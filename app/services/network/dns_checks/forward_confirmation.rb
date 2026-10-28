module Network
  module DnsChecks
    # Forward-confirmed reverse DNS: each name the PTR records point to must resolve back to the same address. Returns
    # one `{ name:, addresses:, confirmed: }` per name, at most LIMIT names.
    class ForwardConfirmation
      include Serviceable

      LIMIT = 3

      def initialize(ip:, names:)
        @ip = IPAddr.new(ip)
        @names = names.first(LIMIT)
      end

      private

      def perform
        Parallel.map(@names, limit: LIMIT) do |name|
          answer = Dns::Query.call(ip: Dns::Resolvers::LOOKUP_IP, name:, type: @ip.ipv4? ? "A" : "AAAA")
          addresses = answer.status == :ok ? answer.answers.first(Checks::Codec::MAX_ANSWERS) : []
          { name:, addresses:, confirmed: addresses.any? { |address| IPAddr.new(address) == @ip } }
        end
      end
    end
  end
end
