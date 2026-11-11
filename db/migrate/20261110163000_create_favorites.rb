class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :submission_favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :submission, null: false, foreign_key: true
      t.timestamps
    end
    add_index :submission_favorites, [ :user_id, :submission_id ], unique: true

    create_table :comment_favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :comment, null: false, foreign_key: true
      t.timestamps
    end
    add_index :comment_favorites, [ :user_id, :comment_id ], unique: true
  end
end
