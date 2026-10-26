class AddCurrentMembershipToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :current_membership, type: :uuid, foreign_key: { to_table: :memberships, on_delete: :nullify }
  end
end
