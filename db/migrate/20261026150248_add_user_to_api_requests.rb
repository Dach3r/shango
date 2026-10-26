class AddUserToApiRequests < ActiveRecord::Migration[8.1]
  def change
    add_reference :api_requests, :user, type: :uuid, foreign_key: { on_delete: :cascade }
    add_check_constraint :api_requests, "collection_id IS NOT NULL OR (user_id IS NOT NULL AND folder_id IS NULL)", name: "api_requests_draft_check"
  end
end
