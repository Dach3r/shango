module Zooming
  extend ActiveSupport::Concern

  COOKIE_KEY = :zoom
  LEVELS = %w[70 80 90 100 110 125 150 175 200].freeze
  DEFAULT = "90".freeze
  NEUTRAL = "100".freeze

  included do
    helper_method :current_zoom
  end

  # Returns the zoom level as a string when it is supported, nil otherwise.
  def self.supported(value)
    value.to_s.presence_in(LEVELS)
  end

  private

  def current_zoom
    Zooming.supported(cookies[COOKIE_KEY]) || DEFAULT
  end
end
