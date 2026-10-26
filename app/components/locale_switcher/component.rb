class LocaleSwitcher::Component < ApplicationComponent
  LABELS = { en: "EN", es: "ES" }.freeze
  NAMES = { en: "English", es: "Español" }.freeze
  BASE = "cursor-pointer rounded-full px-3 py-1 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50"
  ACTIVE = "bg-solid text-on-solid"
  INACTIVE = "text-body hover:text-ink"

  private

  def button_classes(locale)
    class_names(BASE, ACTIVE => current?(locale), INACTIVE => !current?(locale))
  end

  def current?(locale)
    I18n.locale == locale
  end
end
