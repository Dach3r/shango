class CreateLatestExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :latest_executions, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :api_request, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :request_draft, type: :uuid, foreign_key: { on_delete: :cascade }
      t.uuid :execution_id, null: false
      t.text :payload, null: false

      t.timestamps
    end

    add_check_constraint :latest_executions, "(api_request_id IS NULL) <> (request_draft_id IS NULL)", name: "latest_executions_one_subject"
    add_index :latest_executions, %i[user_id api_request_id], unique: true, where: "api_request_id IS NOT NULL", name: "index_latest_executions_on_user_and_api_request"
    add_index :latest_executions, %i[user_id request_draft_id], unique: true, where: "request_draft_id IS NOT NULL", name: "index_latest_executions_on_user_and_request_draft"
    add_index :latest_executions, :execution_id
    add_index :latest_executions, :updated_at
  end
end
