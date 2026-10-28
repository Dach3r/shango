class RemoveUserFromApiRequests < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM api_requests WHERE collection_id IS NULL"
    remove_index :api_requests, name: "index_api_requests_on_drafts"
    remove_check_constraint :api_requests, name: "api_requests_draft_check"
    remove_reference :api_requests, :user, type: :uuid, foreign_key: { on_delete: :cascade }
    change_column_null :api_requests, :collection_id, false
  end

  def down
    change_column_null :api_requests, :collection_id, true
    add_reference :api_requests, :user, type: :uuid, foreign_key: { on_delete: :cascade }
    add_check_constraint :api_requests, "collection_id IS NOT NULL OR (user_id IS NOT NULL AND folder_id IS NULL)", name: "api_requests_draft_check"
    add_index :api_requests, %i[project_id user_id], where: "collection_id IS NULL", name: "index_api_requests_on_drafts"
  end
end
