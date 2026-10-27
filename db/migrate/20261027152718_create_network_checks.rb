class CreateNetworkChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :network_checks, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true, index: false
      t.references :user, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :environment, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false, default: "dns"
      t.string :target, null: false
      t.string :outcome, null: false, default: "ok"
      t.jsonb :input, null: false, default: {}
      t.jsonb :result, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :network_checks, %i[project_id kind created_at]
    add_index :network_checks, %i[project_id kind target created_at], name: "index_network_checks_on_project_kind_target_and_created_at"
    add_check_constraint :network_checks, "kind IN ('dns', 'ports', 'ping')", name: "network_checks_kind_check"
    add_check_constraint :network_checks, "outcome IN ('ok', 'warn', 'bad')", name: "network_checks_outcome_check"
  end
end
