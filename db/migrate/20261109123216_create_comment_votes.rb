class CreateCommentVotes < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :points, :integer, default: 1, null: false

    create_table :comment_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :comment, null: false, foreign_key: true

      t.timestamps
    end

    add_index :comment_votes, [ :user_id, :comment_id ], unique: true
  end
end
