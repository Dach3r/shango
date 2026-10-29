module Network
  module Dns
    # The DNS questions of the tools that read records (email DNS, ASN lookup). They only go to the fixed public
    # resolver, never to a server named by the domain under test, so a record cannot point the check at an internal address.
    module Lookup
      TIMEOUT = 3
      FAILURES = %i[timeout servfail refused error].freeze

      module_function

      def call(name, type)
        Dns::Query.call(ip: Dns::Resolvers::LOOKUP_IP, name:, type:, timeout: TIMEOUT)
      end

      # The resolver could not tell whether the record exists, as opposed to saying it does not.
      def failed?(answer)
        FAILURES.include?(answer.status)
      end

      # Names read from a record come from the domain owner: only well-formed ones are asked about.
      def name?(name)
        name.length <= Target::MAX_LENGTH && name.split(".", -1).all? { |label| label.match?(Target::LABEL) }
      end
    end
  end
end
