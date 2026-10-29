class CreateNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_channels, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :creator, type: :uuid, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.string :kind, null: false, default: "email"
      t.boolean :enabled, null: false, default: true
      t.string :locale, null: false, default: "en"
      t.text :target, null: false
      t.text :signing_secret

      t.timestamps
    end

    add_check_constraint :notification_channels, "kind IN ('email', 'webhook', 'slack', 'discord')", name: "notification_channels_kind_check"
  end
end
