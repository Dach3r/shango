class CreateCheckResults < ActiveRecord::Migration[8.1]
  def change
    create_table :check_results, id: :uuid do |t|
      t.references :uptime_monitor, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :status, null: false
      t.integer :response_ms
      t.integer :http_status
      t.string :error
      t.string :detail
      t.jsonb :timings, null: false, default: {}
      t.datetime :checked_at, null: false
    end

    add_index :check_results, %i[uptime_monitor_id checked_at]
    add_index :check_results, :checked_at, using: :brin
    add_check_constraint :check_results, "status IN ('up', 'down', 'unknown')", name: "check_results_status_check"
  end
end
