module Network
  module Subnets
    # Subnet arithmetic for one IPv4 or IPv6 network, written as a prefix (`192.168.1.0/24`), a mask
    # (`192.168.1.0 255.255.255.0`) or a bare address (a single host). Optionally splits it into longer prefixes and
    # tells whether an address falls inside it. Pure computation: nothing is sent over the network.
    class Calculate
      include Serviceable

      MAX_SUBNETS = 64
      BITS = { 4 => 32, 6 => 128 }.freeze

      def initialize(network:, split: nil, contains: nil, environment: nil)
        @raw = { network:, split:, contains: }
        @environment = environment
      end

      private

      def perform
        values = @raw.transform_values { |raw| Variables.call(raw: raw.to_s, environment: @environment) }
        failed = values.values.find(&:failure?)
        return failed if failed

        network, split, contains = values.values_at(:network, :split, :contains).map { |value| value.record.strip }
        return Result.failure(error: :blank_network) if network.empty?

        address, net = parse(network)
        return Result.failure(error: :invalid_network, token: network) unless net

        data = describe(address, net)
        if split.present?
          subnets = subdivide(net, split)
          return Result.failure(error: :invalid_split, min: net.prefix + 1, max: bits(net)) unless subnets

          data[:split] = subnets
        end
        if contains.present?
          inside = includes?(net, contains)
          return Result.failure(error: :invalid_ip, token: contains) if inside.nil?

          data[:contains] = { address: contains, inside: }
        end
        Result.success(nil, **data)
      end

      def parse(text)
        address = text.split(%r{[\s/]}, 2).first
        [IPAddr.new(address), IPAddr.new(text.sub(/\s+/, "/"))]
      rescue IPAddr::Error
        nil
      end

      def describe(address, net)
        size = 2**(bits(net) - net.prefix)
        first, last = net.to_range.minmax
        data = { family: net.ipv4? ? 4 : 6, address: address.to_s, cidr: cidr(net), network: net.to_s, prefix: net.prefix, scope: scope(net), size: }
        return data.merge(first: first.to_s, last: last.to_s, hosts: size) if net.ipv6?

        hosts = net.prefix >= 31 ? [first, last] : [first.succ, IPAddr.new(last.to_i - 1, Socket::AF_INET)]
        data.merge(netmask: net.netmask.to_s, wildcard: IPAddr.new(size - 1, Socket::AF_INET).to_s,
                   broadcast: (last.to_s if net.prefix < 31), first: hosts.first.to_s, last: hosts.last.to_s,
                   hosts: net.prefix >= 31 ? size : size - 2)
      end

      def subdivide(net, split)
        prefix = Integer(split.delete_prefix("/"), 10)
        return unless prefix > net.prefix && prefix <= bits(net)

        step = 2**(bits(net) - prefix)
        count = 2**(prefix - net.prefix)
        subnets = Array.new([count, MAX_SUBNETS].min) { |index| IPAddr.new(net.to_i + (index * step), net.family).mask(prefix) }
        { prefix:, count:, subnets: subnets.map { |subnet| cidr(subnet) } }
      rescue ArgumentError
        nil
      end

      def includes?(net, text)
        address = IPAddr.new(text)
        address.family == net.family && net.include?(address)
      rescue IPAddr::Error
        nil
      end

      def scope(net)
        if net.loopback? then :loopback
        elsif net.link_local? then :link_local
        elsif net.private? then :private
        else :public
        end
      end

      def cidr(net)
        "#{net}/#{net.prefix}"
      end

      def bits(net)
        BITS.fetch(net.ipv4? ? 4 : 6)
      end
    end
  end
end
