class AddRoleCheckToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :memberships, "role IN ('member', 'owner')", name: "memberships_role_check"
  end
end
