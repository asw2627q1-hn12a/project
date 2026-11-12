namespace :data do
  desc "Import a consistent SQLite backup into an empty PostgreSQL primary database"
  task import_sqlite: :environment do
    abort "DATABASE_URL must select PostgreSQL" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

    require Rails.root.join("lib/sqlite_data_import")
    counts = SqliteDataImport.call(ENV.fetch("SQLITE_BACKUP"))
    counts.each { |table, count| puts "#{table}: #{count} records imported" }
  end
end
