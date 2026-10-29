module Network
  module Rdap
    # Finds the RDAP server that answers for a top-level domain or an IP address, from the IANA bootstrap registries
    # (RFC 9224). The registries change rarely, so each one is cached for a day. Returns the server's base URL, or
    # `no_rdap_service` when the registry lists none over HTTPS (some country-code domains have no RDAP).
    class Bootstrap
      include Serviceable

      BASE = "https://data.iana.org/rdap".freeze
      FILES = { dns: "dns", ipv4: "ipv4", ipv6: "ipv6" }.freeze
      TTL = 24.hours

      def initialize(kind:, key:, deadline: nil)
        @kind = kind
        @key = key
        @deadline = deadline
      end

      private

      def perform
        loaded = load_services
        return loaded if loaded.failure?

        urls = @kind == :dns ? loaded.record.find { |labels, _urls| labels.include?(@key) }&.last : address_urls(loaded.record)
        url = Array(urls).find { |candidate| candidate.to_s.start_with?("https://") }
        return Result.failure(error: :no_rdap_service) unless url

        Result.success(url.end_with?("/") ? url : "#{url}/")
      end

      def load_services
        cache_key = "network/rdap/bootstrap/#{@kind}"
        cached = Rails.cache.read(cache_key)
        return Result.success(cached) if cached

        response = Client.call(url: "#{BASE}/#{FILES.fetch(@kind)}.json", deadline: @deadline)
        return Result.failure(error: :unavailable) if response.failure?

        services = Array(response.record["services"]).select { |entry| entry.is_a?(Array) && entry.size == 2 && entry.all?(Array) }
        return Result.failure(error: :unavailable) if services.empty?

        Rails.cache.write(cache_key, services, expires_in: TTL)
        Result.success(services)
      end

      # The most specific listed network that contains the address.
      def address_urls(services)
        networks = services.flat_map { |prefixes, urls| prefixes.filter_map { |prefix| [network(prefix), urls] } }
        networks.select { |network, _urls| network&.include?(@key) }.max_by { |network, _urls| network.prefix }&.last
      end

      def network(prefix)
        IPAddr.new(prefix.to_s)
      rescue IPAddr::Error
        nil
      end
    end
  end
end
