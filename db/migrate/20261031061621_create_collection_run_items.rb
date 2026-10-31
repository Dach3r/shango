class CreateCollectionRunItems < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_run_items, id: :uuid do |t|
      t.references :collection_run, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :api_request, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :request_name, null: false
      t.string :http_method, null: false, default: "GET"
      t.integer :position, null: false, default: 0
      t.string :status, null: false, default: "pending"
      t.text :url
      t.integer :http_status
      t.integer :duration_ms
      t.jsonb :test_results, null: false, default: []
      t.string :error_kind
      t.text :error_message

      t.timestamps
    end

    add_check_constraint :collection_run_items, "status IN ('pending', 'running', 'passed', 'failed', 'skipped')", name: "collection_run_items_status_check"
    add_index :collection_run_items, %i[collection_run_id position]
  end
end
