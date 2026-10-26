module Theming
  extend ActiveSupport::Concern

  COOKIE_KEY = :theme
  THEMES = %w[system light dark].freeze
  DEFAULT = "system".freeze

  included do
    helper_method :current_theme
  end

  # Returns the theme as a string when it is supported, nil otherwise.
  def self.supported(value)
    value.to_s.presence_in(THEMES)
  end

  private

  def current_theme
    Theming.supported(cookies[COOKIE_KEY]) || DEFAULT
  end
end
