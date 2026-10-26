module Localization
  extend ActiveSupport::Concern

  COOKIE_KEY = :locale

  included do
    around_action :switch_locale
  end

  # Returns the locale as a string when it is supported, nil otherwise.
  def self.supported(value)
    value.to_s.presence_in(I18n.available_locales.map(&:to_s))
  end

  def self.from_cookie(value)
    (supported(value) || I18n.default_locale).to_sym
  end

  private

  def switch_locale(&)
    I18n.with_locale(Localization.from_cookie(cookies[COOKIE_KEY]), &)
  end
end
