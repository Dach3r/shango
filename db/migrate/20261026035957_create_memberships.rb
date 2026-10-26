class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships, id: :uuid do |t|
      t.string :role, null: false, default: "member"
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false

      t.timestamps
    end

    add_index :memberships, %i[user_id project_id], unique: true
  end
end
