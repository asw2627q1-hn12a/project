require "test_helper"
require "open3"

class ApiKeyMigrationTest < ActiveSupport::TestCase
  test "migration preserves legacy users and timestamps and can be reversed" do
    # Connexió independent en memòria: mai desfem l'esquema dels fixtures o de desenvolupament.
    script = <<~RUBY
      require "active_record"
      require #{Rails.root.join("db/migrate/20261115170734_add_api_key_to_users.rb").to_s.inspect}
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      ActiveRecord::Migration.verbose = false
      connection = ActiveRecord::Base.connection
      connection.create_table(:users) do |table|
        table.string :username
        table.string :email
        table.text :about
        table.timestamps null: false
      end
      legacy_user = Class.new(ActiveRecord::Base) { self.table_name = "users" }
      2.times do |i|
        legacy_user.create!(username: "legacy_" + i.to_s, email: "legacy_" + i.to_s + "@example.test",
          about: "Keep this", created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 2))
      end
      original = legacy_user.order(:id).map(&:attributes)

      migration = AddApiKeyToUsers.new
      migration.migrate(:up)
      legacy_user.reset_column_information
      migrated = legacy_user.order(:id).map(&:attributes)
      abort "Existing data changed" unless original == migrated.map { |row| row.except("api_key") }
      keys = migrated.map { |row| row.fetch("api_key") }
      abort "Missing or duplicate keys" unless keys.all? { |key| key&.length == 32 } && keys.uniq.length == 2
      abort "Missing unique index" unless connection.index_exists?(:users, :api_key, unique: true)
      abort "Column is nullable" if connection.columns(:users).find { |column| column.name == "api_key" }.null

      migration.migrate(:down)
      legacy_user.reset_column_information
      abort "Rollback changed existing data" unless original == legacy_user.order(:id).map(&:attributes)
    RUBY

    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", script)

    assert status.success?, stderr
  end
end
