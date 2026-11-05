class AddTextToSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_column :submissions, :text, :text
  end
end
