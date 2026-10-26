class AddCurrentEnvironmentToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_reference :memberships, :current_environment, type: :uuid, null: true, foreign_key: { to_table: :environments, on_delete: :nullify }
  end
end
