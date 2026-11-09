class CreateSubmissionHides < ActiveRecord::Migration[8.0]
  def change
    create_table :submission_hides do |t|
      t.references :user, null: false, foreign_key: true
      t.references :submission, null: false, foreign_key: true

      t.timestamps
    end

    add_index :submission_hides, [ :user_id, :submission_id ], unique: true
  end
end
