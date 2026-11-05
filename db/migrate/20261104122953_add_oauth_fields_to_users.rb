class AddOauthFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :provider, :string
    # Proveïdor extern, per exemple "github".

    add_column :users, :uid, :string
    # Identificador únic retornat per GitHub.

    add_column :users, :avatar, :string, default: "default-avatar.png"
    # Avatar provisional fins que arribi Active Storage.

    add_column :users, :banner, :string, default: "default-banner.png"
    # Banner provisional per a la US #45.

    add_index :users, [ :provider, :uid ], unique: true
    # Impedeix duplicar el mateix compte extern.
  end
end
