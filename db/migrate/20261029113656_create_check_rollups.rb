class CreateCheckRollups < ActiveRecord::Migration[8.1]
  def change
    create_table :check_rollups, id: :uuid do |t|
      t.references :uptime_monitor, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.datetime :hour, null: false
      t.integer :checks, null: false, default: 0
      t.integer :failures, null: false, default: 0
      t.bigint :response_ms_sum, null: false, default: 0
      t.integer :response_ms_max, null: false, default: 0
    end

    add_index :check_rollups, %i[uptime_monitor_id hour], unique: true
    add_index :check_rollups, :hour
  end
end
