class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true, index: false
      t.references :actor, type: :uuid, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :target, type: :uuid, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :kind, null: false
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :audit_events, %i[project_id created_at]
    add_check_constraint :audit_events, "kind IN ('member_invited', 'invitation_accepted', 'invitation_revoked', 'role_changed', 'member_revoked', 'member_left', 'ownership_transferred')", name: "audit_events_kind_check"
  end
end
