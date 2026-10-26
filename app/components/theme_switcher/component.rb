class ThemeSwitcher::Component < ApplicationComponent
  ICONS = { "system" => "monitor", "light" => "sun", "dark" => "moon" }.freeze
  BASE = "flex size-9 cursor-pointer items-center justify-center transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50 focus-visible:ring-inset"
  ACTIVE = "bg-solid text-on-solid"
  INACTIVE = "text-body hover:bg-ink/5 hover:text-ink"

  private

  def button_classes(theme)
    class_names(BASE, ACTIVE => current?(theme), INACTIVE => !current?(theme))
  end

  def current?(theme)
    helpers.current_theme == theme
  end
end
