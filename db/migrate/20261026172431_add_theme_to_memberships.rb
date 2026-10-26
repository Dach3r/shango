class AddThemeToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :theme, :string, default: "default", null: false
    add_check_constraint :memberships, "theme IN ('default', 'blue', 'green', 'yellow', 'red', 'ocean')", name: "memberships_theme_check"
  end
end
