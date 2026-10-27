module Network
  module DnsChecks
    # Asks the authoritative nameservers of a domain and a fixed set of public resolvers for one record type, in
    # parallel, and reports what each answered. With an expected value every row says whether it matches, which is
    # how DNS propagation is read. No user-supplied resolvers: queries only go to the fixed list and to nameservers
    # named by the domain itself, and those pass the outbound guard.
    class Run
      include Serviceable

      TIMEOUT = 3
      CONCURRENCY = 20

      def initialize(domain:, type:, expected: nil, environment: nil)
        @domain = domain
        @type = type.to_s.upcase
        @expected = expected.to_s.strip
        @environment = environment
      end

      private

      def perform
        return Result.failure(error: :invalid_type) unless Dns::Query::TYPES.key?(@type)

        target = Target.call(raw: @domain, environment: @environment)
        return target if target.failure?

        expected = Variables.call(raw: @expected, environment: @environment)
        return expected if expected.failure?

        @expected = expected.record.strip
        host = target.record
        resolvers = Dns::Resolvers.authoritative(host) + Dns::Resolvers::PUBLIC
        rows = Parallel.map(resolvers, limit: CONCURRENCY) { |resolver| check(resolver, host) }
        Result.success(nil, host:, type: @type, expected: @expected.presence, rows:, summary: summarize(rows))
      end

      def check(resolver, host)
        return row(resolver, status: :unresolved) unless resolver.ip
        return row(resolver, status: :blocked) if SsrfPolicy.enabled? && SsrfPolicy.blocked?(resolver.ip)

        answer = Dns::Query.call(ip: resolver.ip, name: host, type: @type, timeout: TIMEOUT)
        row(resolver, **answer.to_h)
      end

      def row(resolver, status:, answers: [], ttl: nil, ms: nil)
        row = Dns::Row.new(name: resolver.name, ip: resolver.ip, group: resolver.group, status:, answers:, ttl:, ms:, match: nil)
        row.with(match: match_for(row))
      end

      def match_for(row)
        return if @expected.empty?
        return :no_answer unless row.answered?

        row.answers.map { |answer| normalize(answer) }.include?(normalize(@expected)) ? :match : :mismatch
      end

      def normalize(value)
        value.strip.delete_prefix('"').delete_suffix('"').delete_suffix(".").downcase
      end

      def summarize(rows)
        answered = rows.select(&:answered?)
        {
          total: rows.size, answered: answered.size, matched: rows.count { |row| row.match == :match },
          agree: answered.map { |row| row.answers.map { |answer| normalize(answer) }.sort }.uniq.size <= 1
        }
      end
    end
  end
end
