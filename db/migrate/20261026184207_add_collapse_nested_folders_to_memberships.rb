class AddCollapseNestedFoldersToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :collapse_nested_folders, :boolean, default: true, null: false
  end
end
