module ApiClient
  # Hides secrets (secret variables, credentials, tokens) from anything that gets stored or displayed.
  class Masker
    MASK = "••••••".freeze
    MIN_SECRET_LENGTH = 3
    SENSITIVE_HEADERS = %w[authorization proxy-authorization x-api-key x-auth-token cookie].freeze

    def initialize(secrets)
      @secrets = secrets.map(&:to_s).select { |secret| secret.length >= MIN_SECRET_LENGTH }.uniq.sort_by { |secret| -secret.length }
    end

    def string(text)
      return text if text.blank?

      @secrets.reduce(text.to_s) { |masked, secret| masked.gsub(secret, MASK) }
    end

    # Header pairs as sent: sensitive header names are hidden entirely.
    def request_headers(pairs)
      pairs.map do |name, value|
        [name, SENSITIVE_HEADERS.include?(name.to_s.downcase) ? MASK : string(value)]
      end
    end

    def response_headers(pairs)
      pairs.map { |name, value| [name, string(value)] }
    end
  end
end
