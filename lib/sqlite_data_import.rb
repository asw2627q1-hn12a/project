require "sqlite3"

# Copies a consistent SQLite backup into an empty, already migrated primary DB.
# Inserts bypass callbacks so votes, points and attachments retain their original values.
class SqliteDataImport
  TABLES = %w[
    users submissions active_storage_blobs comments
    submission_votes comment_votes submission_hides submission_favorites comment_favorites
    active_storage_attachments active_storage_variant_records
  ].freeze

  def self.call(path)
    raise ArgumentError, "SQLite backup not found" unless File.file?(path)

    source = SQLite3::Database.new(path, readonly: true)
    source.results_as_hash = true
    connection = ActiveRecord::Base.connection
    counts = {}

    source.transaction do
      rows_by_table = TABLES.to_h do |table|
        exists = source.get_first_value("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", table)
        [ table, exists ? source.execute("SELECT * FROM #{table}") : [] ]
      end

      # Files from local disk must be transferred separately before switching servers.
      attached_blob_ids = rows_by_table.fetch("active_storage_attachments").map { |row| row.fetch("blob_id") }
      local_images = rows_by_table.fetch("active_storage_blobs").any? do |row|
        attached_blob_ids.include?(row.fetch("id")) && row.fetch("service_name") != "object_storage"
      end
      raise ArgumentError, "Transfer attached local files to object_storage before importing" if local_images

      connection.transaction do
        if connection.adapter_name == "PostgreSQL"
          connection.execute(<<~SQL)
            LOCK TABLE users, submissions, active_storage_blobs, comments,
              submission_votes, comment_votes, submission_hides,
              submission_favorites, comment_favorites,
              active_storage_attachments, active_storage_variant_records
            IN EXCLUSIVE MODE
          SQL
        end

        occupied = TABLES.any? do |table|
          connection.select_value("SELECT 1 FROM #{connection.quote_table_name(table)} LIMIT 1")
        end
        raise ArgumentError, "Target database must be empty; no records were changed" if occupied

        TABLES.each do |table|
          rows = rows_by_table.fetch(table)
          model = Class.new(ActiveRecord::Base) { self.table_name = table }
          # Insert every comment first, then restore parents, regardless of ID order.
          records = table == "comments" ? rows.map { |row| row.merge("parent_id" => nil) } : rows
          records.each_slice(100) { |batch| model.insert_all!(batch, record_timestamps: false) }
          counts[table] = rows.length
        end

        rows_by_table.fetch("comments").each do |row|
          next unless row["parent_id"]

          connection.execute(
            "UPDATE comments SET parent_id = #{connection.quote(row.fetch('parent_id'))} WHERE id = #{connection.quote(row.fetch('id'))}"
          )
        end

        if connection.adapter_name == "PostgreSQL"
          TABLES.each { |table| connection.reset_pk_sequence!(table) }
        end
      end
    end

    counts
  ensure
    source&.close
  end
end
