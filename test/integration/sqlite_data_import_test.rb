require "test_helper"
require Rails.root.join("lib/sqlite_data_import")

class SqliteDataImportTest < ActiveSupport::TestCase
  setup do
    connection = ActiveRecord::Base.connection
    if connection.adapter_name == "PostgreSQL"
      @sequence_values = SqliteDataImport::TABLES.to_h do |table|
        [ table, connection.select_value("SELECT MAX(id) FROM #{table}") || 1 ]
      end
    end
    # These deletes affect transactional test fixtures only, never the source backup.
    SqliteDataImport::TABLES.reverse_each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
    @backup_path = Rails.root.join("tmp", "sqlite-import-#{SecureRandom.hex}.sqlite3")
  end

  teardown do
    # PostgreSQL sequences do not roll back with the transactional fixtures.
    @sequence_values&.each do |table, value|
      ActiveRecord::Base.connection.set_pk_sequence!(table, value)
    end
    File.delete(@backup_path) if @backup_path && File.exist?(@backup_path)
  end

  test "imports IDs points votes and reply parents without modifying the source backup" do
    write_backup(valid_rows)
    original_backup = File.binread(@backup_path)

    counts = SqliteDataImport.call(@backup_path)

    assert_equal 2, counts.fetch("users")
    assert_equal "Imported author", User.find(3).username
    assert_equal 8, Submission.find(19).points
    assert_equal 11, Comment.find(9).parent_id
    assert_equal 19, SubmissionVote.find(7).submission_id
    assert_equal "persisted-r2-key", User.find(3).banner.blob.key
    assert_equal "object_storage", User.find(3).banner.blob.service_name
    assert_equal original_backup, File.binread(@backup_path)
    assert_operator User.create!(username: "New user").id, :>, 4
  end

  test "refuses to import into an occupied target without changing its data" do
    user = User.create!(username: "Existing user")
    write_backup(valid_rows)

    assert_raises(ArgumentError) { SqliteDataImport.call(@backup_path) }

    assert_equal [ user.id ], User.pluck(:id)
    assert_equal "Existing user", user.reload.username
  end

  test "rolls back imported rows if a foreign key is invalid" do
    rows = valid_rows
    rows.fetch("comments").first["parent_id"] = 999
    write_backup(rows)

    assert_raises(ActiveRecord::StatementInvalid) { SqliteDataImport.call(@backup_path) }

    assert_equal 0, User.count
    assert_equal 0, Submission.count
    assert_equal 0, Comment.count
    assert_equal 0, SubmissionVote.count
  end

  test "refuses local attachments that would be lost when the web server changes" do
    rows = valid_rows.merge(
      "active_storage_blobs" => [ { "id" => 1, "service_name" => "local" } ],
      "active_storage_attachments" => [ { "id" => 1, "blob_id" => 1 } ]
    )
    write_backup(rows)

    error = assert_raises(ArgumentError) { SqliteDataImport.call(@backup_path) }

    assert_includes error.message, "object_storage"
    assert_equal 0, User.count
  end

  private

  def valid_rows
    timestamps = { "created_at" => "2026-11-01 12:00:00", "updated_at" => "2026-11-01 12:00:00" }
    {
      "users" => [
        timestamps.merge("id" => 3, "username" => "Imported author"),
        timestamps.merge("id" => 4, "username" => "Imported voter")
      ],
      "submissions" => [ timestamps.merge("id" => 19, "title" => "Imported submission", "submission_type" => "ask", "user_id" => 3, "points" => 8) ],
      "comments" => [
        timestamps.merge("id" => 9, "body" => "Reply", "submission_id" => 19, "user_id" => 4, "parent_id" => 11, "points" => 1),
        timestamps.merge("id" => 11, "body" => "Parent", "submission_id" => 19, "user_id" => 3, "parent_id" => nil, "points" => 1)
      ],
      "submission_votes" => [ timestamps.merge("id" => 7, "user_id" => 4, "submission_id" => 19) ],
      "active_storage_blobs" => [ {
        "id" => 5, "key" => "persisted-r2-key", "filename" => "banner.png",
        "content_type" => "image/png", "metadata" => "{}", "service_name" => "object_storage",
        "byte_size" => 12, "checksum" => "test-checksum", "created_at" => timestamps.fetch("created_at")
      } ],
      "active_storage_attachments" => [ {
        "id" => 2, "name" => "banner", "record_type" => "User", "record_id" => 3,
        "blob_id" => 5, "created_at" => timestamps.fetch("created_at")
      } ]
    }
  end

  def write_backup(tables)
    source = SQLite3::Database.new(@backup_path.to_s)
    tables.each do |table, rows|
      columns = rows.first.keys
      source.execute("CREATE TABLE #{table} (#{columns.join(', ')})")
      rows.each do |row|
        source.execute("INSERT INTO #{table} VALUES (#{([ '?' ] * columns.length).join(', ')})", row.values)
      end
    end
  ensure
    source&.close
  end
end
