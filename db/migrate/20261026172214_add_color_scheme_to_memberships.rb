class AddColorSchemeToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :color_scheme, :string, default: "system", null: false
    add_check_constraint :memberships, "color_scheme IN ('system', 'light', 'dark')", name: "memberships_color_scheme_check"
  end
end
