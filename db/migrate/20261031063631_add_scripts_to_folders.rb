class AddScriptsToFolders < ActiveRecord::Migration[8.1]
  def change
    add_column :folders, :pre_request_script, :text
    add_column :folders, :post_response_script, :text
  end
end
