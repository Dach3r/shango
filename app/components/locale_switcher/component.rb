class LocaleSwitcher::Component < ApplicationComponent
  LABELS = { en: "EN", es: "ES" }.freeze
  NAMES = { en: "English", es: "Español" }.freeze
  BASE = "h-9 cursor-pointer px-3.5 font-mono text-xs font-medium tracking-widest transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50 focus-visible:ring-inset"
  ACTIVE = "bg-solid text-on-solid"
  INACTIVE = "text-body hover:bg-ink/5 hover:text-ink"

  private

  def button_classes(locale)
    class_names(BASE, ACTIVE => current?(locale), INACTIVE => !current?(locale))
  end

  def current?(locale)
    I18n.locale == locale
  end
end
