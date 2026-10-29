module Network
  module Lookups
    # The autonomous system that announces an address, from Team Cymru's IP-to-ASN mapping over DNS, asked of the
    # fixed public resolver. Returns a Result with the list of origins (empty when nothing announces the address),
    # or `unavailable` when the resolver could not answer.
    class Asn
      include Serviceable

      MAX_ORIGINS = 3

      def initialize(ip:)
        @ip = ip
      end

      private

      def perform
        answer = Dns::Lookup.call(origin_name, "TXT")
        return Result.failure(error: :unavailable) if Dns::Lookup.failed?(answer)

        fields = fields(answer.answers.first)
        numbers = fields.first.to_s.split.grep(/\A\d+\z/).first(MAX_ORIGINS)
        names = Parallel.map(numbers, limit: MAX_ORIGINS) { |number| name(number) }
        Result.success(numbers.zip(names).map { |number, name| { number:, name:, prefix: Clean.text(fields[1]), country: Clean.text(fields[2]), registry: Clean.text(fields[3]), allocated: Clean.text(fields[4]) } })
      end

      def origin_name
        reverse = @ip.reverse
        @ip.ipv4? ? "#{reverse.delete_suffix(".in-addr.arpa")}.origin.asn.cymru.com" : "#{reverse.delete_suffix(".ip6.arpa")}.origin6.asn.cymru.com"
      end

      def fields(text)
        text.to_s.split("|").map(&:strip)
      end

      def name(number)
        answer = Dns::Lookup.call("AS#{number}.asn.cymru.com", "TXT")
        Clean.text(fields(answer.answers.first)[4])
      end
    end
  end
end
