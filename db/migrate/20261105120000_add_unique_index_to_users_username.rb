class AddUniqueIndexToUsersUsername < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :username, unique: true
    # Garanteix a nivell de BD que no hi ha dos usuaris amb el mateix username
    # (la validació de Ruby sola no evita la condició de carrera).
  end
end
