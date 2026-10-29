module Theming
  extend ActiveSupport::Concern

  COOKIE_KEY = :theme
  THEMES = %w[system light dark].freeze
  DEFAULT = "system".freeze

  included do
    helper_method :current_theme, :current_palette, :membership_theme?
  end

  # Returns the theme as a string when it is supported, nil otherwise.
  def self.supported(value)
    value.to_s.presence_in(THEMES)
  end

  private

  # Signed-in members use the scheme saved on their membership; public pages use the cookie.
  def current_theme
    membership = theme_membership
    return Theming.supported(cookies[COOKIE_KEY]) || DEFAULT unless membership

    Membership.pinned_scheme(membership.theme) || membership.color_scheme
  end

  def current_palette
    theme_membership&.theme || Membership::THEMES.fetch(:mono)
  end

  # True when the theme comes from the membership, so the cookie switcher has no effect.
  def membership_theme?
    theme_membership.present?
  end

  def theme_membership
    current_membership if request.env["warden"]&.authenticated?(:user) && respond_to?(:current_membership, true)
  end
end
