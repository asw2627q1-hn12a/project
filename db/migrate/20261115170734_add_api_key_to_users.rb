require "active_support/core_ext/securerandom"

class AddApiKeyToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :api_key, :string
    add_index :users, :api_key, unique: true

    # No usem User: els callbacks i les validacions poden canviar en el futur.
    migration_user = Class.new(ActiveRecord::Base) do
      self.table_name = "users"
    end
    migration_user.reset_column_information
    migration_user.find_each do |user|
      user.update_columns(api_key: SecureRandom.base58(32))
    end

    change_column_null :users, :api_key, false
  end

  def down
    remove_index :users, :api_key
    remove_column :users, :api_key
  end
end
