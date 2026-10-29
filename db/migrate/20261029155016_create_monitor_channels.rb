class CreateMonitorChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :monitor_channels, id: :uuid do |t|
      t.references :uptime_monitor, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :notification_channel, type: :uuid, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :monitor_channels, %i[uptime_monitor_id notification_channel_id], unique: true
  end
end
