module ApiClient
  # Builds the Faraday connection used for every outbound call (requests and OAuth token calls).
  class Connection
    OPEN_TIMEOUT = 10

    class InvalidUrl < StandardError; end

    def self.build(url:, timeout:, verify_ssl: true, multipart: false, timing: Timing.new)
      uri = URI.parse(url.to_s)
      raise InvalidUrl, "Only http and https URLs are supported" unless uri.is_a?(URI::HTTP) && uri.host.present?

      pinned_address = timing.measure(:dns) { Network::SsrfPolicy.check!(uri.hostname) }

      Faraday.new do |faraday|
        faraday.request :multipart if multipart
        faraday.options.timeout = timeout
        faraday.options.open_timeout = [timeout, OPEN_TIMEOUT].min
        faraday.ssl.verify = verify_ssl
        faraday.adapter :net_http do |http|
          http.ipaddr = pinned_address if pinned_address
          timing.probe(http)
        end
      end
    rescue URI::InvalidURIError => error
      raise InvalidUrl, error.message
    end
  end
end
