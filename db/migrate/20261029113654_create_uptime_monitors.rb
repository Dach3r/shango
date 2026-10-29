class CreateUptimeMonitors < ActiveRecord::Migration[8.1]
  def change
    create_table :uptime_monitors, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :creator, type: :uuid, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :environment, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :api_request, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.string :kind, null: false, default: "http"
      t.boolean :enabled, null: false, default: true
      t.boolean :environment_required, null: false, default: false
      t.integer :interval, null: false, default: 300
      t.integer :timeout, null: false, default: 10
      t.integer :confirmations, null: false, default: 2
      t.jsonb :settings, null: false, default: {}
      t.string :push_token_digest
      t.string :status, null: false, default: "pending"
      t.integer :failures, null: false, default: 0
      t.integer :config_version, null: false, default: 0
      t.datetime :next_check_at
      t.datetime :last_checked_at
      t.datetime :last_pinged_at
      t.datetime :last_status_change_at

      t.timestamps
    end

    add_index :uptime_monitors, %i[project_id status]
    add_index :uptime_monitors, :next_check_at, where: "enabled"
    add_index :uptime_monitors, :push_token_digest, unique: true, where: "push_token_digest IS NOT NULL"
    add_check_constraint :uptime_monitors, "kind IN ('http', 'tcp', 'ssl', 'domain', 'push')", name: "uptime_monitors_kind_check"
    add_check_constraint :uptime_monitors, "status IN ('pending', 'up', 'down')", name: "uptime_monitors_status_check"
  end
end
