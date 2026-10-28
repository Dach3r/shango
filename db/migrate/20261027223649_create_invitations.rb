class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true, index: false
      t.references :inviter, type: :uuid, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :invitations, :token_digest, unique: true
    add_index :invitations, %i[project_id email], unique: true, where: "accepted_at IS NULL AND revoked_at IS NULL", name: "index_invitations_on_project_id_and_email_pending"
    add_check_constraint :invitations, "role IN ('member', 'owner')", name: "invitations_role_check"
  end
end
