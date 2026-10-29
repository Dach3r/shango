class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :uptime_monitor, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :cause, null: false
      t.string :detail
      t.datetime :started_at, null: false
      t.datetime :resolved_at
      t.string :resolution

      t.timestamps
    end

    add_index :incidents, %i[uptime_monitor_id started_at]
    add_index :incidents, :uptime_monitor_id, unique: true, where: "resolved_at IS NULL", name: "index_incidents_on_open_uptime_monitor"
    add_check_constraint :incidents, "resolution IN ('recovered', 'paused')", name: "incidents_resolution_check"
  end
end
