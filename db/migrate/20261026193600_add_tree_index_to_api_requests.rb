class AddTreeIndexToApiRequests < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :api_requests, %i[project_id collection_id folder_id position], name: "index_api_requests_on_tree_order", algorithm: :concurrently
  end
end
