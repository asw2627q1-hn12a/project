class CreateSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :submissions do |t|
      t.string :title, null: false
      t.string :url
      t.integer :points, default: 1, null: false
      t.string :submission_type, default: "url", null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
