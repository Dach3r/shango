class AddOmarchyThemesToMembershipsThemeCheck < ActiveRecord::Migration[8.1]
  OLD = %w[default blue green yellow red purple rose orange mono ocean forest midnight nord dracula gruvbox solarized sunset coffee cyberpunk graphite].freeze
  OMARCHY = %w[
    vulkanite virginia_tech venice_from_above vague van_gogh vault winslow unit_eva_001 turner
    waveform_dark terminus synctax starsend spectrum saule santa_fe robzee84 rose_pine_moon
    roadster_dark red_pill periphery outpost neptune alberta arc_blueberry astral azure_glow
    bauhaus black_sand
  ].freeze

  def up
    replace_check(OLD + OMARCHY)
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
