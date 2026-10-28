class ChangeDefaultThemeOnMemberships < ActiveRecord::Migration[8.1]
  def change
    change_column_default :memberships, :theme, from: "default", to: "mono"
  end
end
