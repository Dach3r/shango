class AddDraftsIndexToApiRequests < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :api_requests, %i[project_id user_id], where: "collection_id IS NULL", name: "index_api_requests_on_drafts", algorithm: :concurrently
  end
end
