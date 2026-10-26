class AddMoreThemesToMembershipsThemeCheck < ActiveRecord::Migration[8.1]
  OLD = %w[default blue green yellow red ocean].freeze
  NEW = (OLD + %w[purple rose orange forest midnight nord dracula gruvbox solarized sunset coffee cyberpunk mono]).freeze

  def up
    replace_check(NEW)
  end

  def down
    replace_check(OLD)
  end

  private

  def replace_check(themes)
    remove_check_constraint :memberships, name: "memberships_theme_check"
    add_check_constraint :memberships, "theme IN (#{themes.map { |t| "'#{t}'" }.join(", ")})", name: "memberships_theme_check"
  end
end
