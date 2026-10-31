class AddScriptsToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :pre_request_script, :text
    add_column :collections, :post_response_script, :text
  end
end
