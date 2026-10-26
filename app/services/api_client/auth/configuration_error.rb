module ApiClient
  module Auth
    # Raised by a strategy when its saved configuration cannot produce credentials.
    class ConfigurationError < StandardError; end
  end
end
