class CreateNotificationDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_deliveries, id: :uuid do |t|
      t.references :notification_channel, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :incident, type: :uuid, null: true, foreign_key: { on_delete: :cascade }
      t.string :event, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.string :error
      t.string :detail
      t.datetime :sent_at

      t.timestamps
    end

    add_index :notification_deliveries, %i[notification_channel_id incident_id event], unique: true, where: "incident_id IS NOT NULL",
                                                                                         name: "index_notification_deliveries_once_per_event"
    add_index :notification_deliveries, %i[notification_channel_id created_at]
    add_index :notification_deliveries, :created_at, using: :brin
    add_check_constraint :notification_deliveries, "event IN ('incident_opened', 'incident_resolved', 'test')", name: "notification_deliveries_event_check"
    add_check_constraint :notification_deliveries, "status IN ('pending', 'sent', 'failed')", name: "notification_deliveries_status_check"
  end
end
