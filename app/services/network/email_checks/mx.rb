module Network
  module EmailChecks
    # Lists the mail servers of a domain by preference and checks that each one resolves to an address, which an MX
    # must do directly: a name that is only an alias (CNAME) is not allowed to be one.
    class Mx
      include Serviceable

      MAX_RECORDS = 10

      def initialize(domain:)
        @domain = domain
      end

      private

      def perform
        answer = Dns::Lookup.call(@domain, "MX")
        return Section.new(data: nil, findings: [Section.finding("mx.lookup_failed", "warn", name: @domain)]) if Dns::Lookup.failed?(answer)

        records = answer.status == :ok ? answer.answers.map { |text| preference_and_exchange(text) } : []
        return Section.new(data: nil, findings: [Section.finding("mx.missing", "warn")]) if records.empty?
        return Section.new(data: { null: true, records: [] }, findings: []) if records.all? { |_preference, exchange| exchange == "." }

        rows = Parallel.map(records.sort.first(MAX_RECORDS), limit: 5) { |preference, exchange| { preference:, exchange:, status: status(exchange) } }
        Section.new(data: { null: false, records: rows }, findings: rows.filter_map { |row| finding(row) })
      end

      def preference_and_exchange(text)
        preference, exchange = text.split(" ", 2)
        [preference.to_i, exchange.to_s.downcase.delete_suffix(".").presence || "."]
      end

      def status(exchange)
        return "unresolved" unless Dns::Lookup.name?(exchange)

        answers = %w[A AAAA].map { |type| Dns::Lookup.call(exchange, type) }
        return "ok" if answers.any? { |answer| answer.status == :ok }
        return "cname" if answers.any? { |answer| answer.status == :cname }

        answers.any? { |answer| Dns::Lookup.failed?(answer) } ? "unavailable" : "unresolved"
      end

      def finding(row)
        host = row[:exchange]
        case row[:status]
        when "cname" then Section.finding("mx.cname", "bad", host:)
        when "unresolved" then Section.finding("mx.unresolved", "bad", host:)
        when "unavailable" then Section.finding("mx.lookup_failed", "warn", name: host)
        end
      end
    end
  end
end
