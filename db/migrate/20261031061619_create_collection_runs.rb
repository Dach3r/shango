class CreateCollectionRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_runs, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :collection, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :folder, type: :uuid, foreign_key: { on_delete: :nullify }
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :environment, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :status, null: false, default: "queued"
      t.integer :total_count, null: false, default: 0
      t.integer :passed_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.jsonb :options, null: false, default: {}
      t.string :error
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_check_constraint :collection_runs, "status IN ('queued', 'running', 'completed', 'failed', 'cancelled')", name: "collection_runs_status_check"
    add_index :collection_runs, %i[collection_id created_at]
    add_index :collection_runs, %i[user_id status]
  end
end
