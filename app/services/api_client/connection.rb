module ApiClient
  # Builds the Faraday connection used for every outbound call (requests and OAuth token calls). The address comes
  # from the outbound guard, or from `resolve` (a callable taking the host name, returning the address to pin or
  # raising Network::SsrfPolicy::Blocked) when the caller needs stricter rules.
  class Connection
    OPEN_TIMEOUT = 10

    class InvalidUrl < StandardError; end

    def self.build(url:, timeout:, verify_ssl: true, multipart: false, timing: Timing.new, resolve: nil)
      uri = URI.parse(url.to_s)
      raise InvalidUrl, "Only http and https URLs are supported" unless uri.is_a?(URI::HTTP) && uri.host.present?

      pinned_address = timing.measure(:dns) { resolve ? resolve.call(uri.hostname) : Network::SsrfPolicy.check!(uri.hostname) }

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
