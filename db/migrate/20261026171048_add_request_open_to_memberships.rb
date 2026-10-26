class AddRequestOpenToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :request_open, :string, default: "click", null: false
    add_check_constraint :memberships, "request_open IN ('click', 'double_click')", name: "memberships_request_open_check"
  end
end
