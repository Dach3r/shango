class AddAssertionsAndExtractorsToFolders < ActiveRecord::Migration[8.1]
  def change
    add_column :folders, :assertions, :jsonb, default: [], null: false
    add_column :folders, :extractors, :jsonb, default: [], null: false
  end
end
