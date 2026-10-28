class AddRequestDraftToRequestTabs < ActiveRecord::Migration[8.1]
  def change
    add_reference :request_tabs, :request_draft, type: :uuid, foreign_key: { on_delete: :cascade }
    change_column_null :request_tabs, :api_request_id, true
    add_index :request_tabs, %i[user_id request_draft_id], unique: true, where: "request_draft_id IS NOT NULL", name: "index_request_tabs_on_user_and_request_draft"
    add_check_constraint :request_tabs, "(api_request_id IS NULL) <> (request_draft_id IS NULL)", name: "request_tabs_target_check"
  end
end
