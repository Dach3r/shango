class AddFolderToggleToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :folder_toggle, :string, default: "double_click", null: false
    add_check_constraint :memberships, "folder_toggle IN ('click', 'double_click')", name: "memberships_folder_toggle_check"
  end
end
