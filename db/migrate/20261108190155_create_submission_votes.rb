class CreateSubmissionVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :submission_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :submission, null: false, foreign_key: true

      t.timestamps
    end

    add_index :submission_votes,
              [ :user_id, :submission_id ],
              unique: true
  end
end
