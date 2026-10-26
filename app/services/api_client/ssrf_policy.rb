module ApiClient
  # Outbound request guard. Self-hosted installs legitimately call private addresses, so the
  # block list is opt-in: set SHANGO_BLOCK_PRIVATE_NETWORKS=true on shared or cloud deployments.
  class SsrfPolicy
    class Blocked < StandardError; end

    BLOCKED_RANGES = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
      192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
      ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8
    ].map { |range| IPAddr.new(range) }.freeze

    class << self
      def enabled?
        ActiveModel::Type::Boolean.new.cast(ENV["SHANGO_BLOCK_PRIVATE_NETWORKS"]) == true
      end

      # Returns the address to pin the connection to (nil when the policy is off).
      # Raises Blocked when any resolved address is private and the policy is on.
      def check!(host)
        return unless enabled?

        addresses = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address).uniq
        addresses.each do |address|
          raise Blocked, "#{host} resolves to a private address (#{address})" if blocked?(address)
        end
        addresses.first
      end

      def blocked?(address)
        ip = IPAddr.new(address).native
        BLOCKED_RANGES.any? { |range| range.family == ip.family && range.include?(ip) }
      end
    end
  end
end
