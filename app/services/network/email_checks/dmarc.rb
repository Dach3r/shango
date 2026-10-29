module Network
  module EmailChecks
    # Reads the DMARC policy of a domain. A subdomain without a record of its own is covered by the one of its parent,
    # so the parents are asked too and the result says where the record was found.
    class Dmarc
      include Serviceable

      VERSION = /\Av=DMARC1\s*(;|\z)/i
      POLICIES = %w[none quarantine reject].freeze

      def initialize(domain:)
        @domain = domain
      end

      private

      def perform
        labels = @domain.split(".")
        names = Array.new([labels.size - 1, 1].max) { |index| labels[index..].join(".") }
        answers = Parallel.map(names, limit: 4) { |name| [name, Dns::Lookup.call("_dmarc.#{name}", "TXT")] }
        found = answers.map { |name, answer| [name, records(answer)] }.find { |_name, records| records.any? }
        return missing(answers) unless found

        name, records = found
        tags = Tags.parse(records.first)
        data = { record: records.first, domain: name, policy: tags["p"]&.downcase, subdomain_policy: tags["sp"]&.downcase, pct: tags["pct"], rua: tags["rua"].to_s.split(",").map(&:strip).compact_blank }
        Section.new(data:, findings: [(Section.finding("dmarc.multiple", "bad") if records.size > 1), *findings(data)].compact)
      end

      def records(answer)
        answer.status == :ok ? answer.answers.select { |text| text.match?(VERSION) } : []
      end

      def missing(answers)
        failed = answers.find { |_name, answer| Dns::Lookup.failed?(answer) }
        finding = failed ? Section.finding("dmarc.lookup_failed", "warn", name: "_dmarc.#{failed.first}") : Section.finding("dmarc.missing", "bad")
        Section.new(data: nil, findings: [finding])
      end

      def findings(data)
        policy = data[:policy]
        [
          *policy_findings(policy, data[:subdomain_policy]),
          (Section.finding("dmarc.partial", "warn", pct: data[:pct]) if policy.in?(%w[quarantine reject]) && data[:pct].to_s.match?(/\A\d+\z/) && data[:pct].to_i < 100),
          (Section.finding("dmarc.no_reports", "warn") if data[:rua].empty?)
        ].compact
      end

      def policy_findings(policy, subdomain_policy)
        return [Section.finding("dmarc.invalid_policy", "bad")] unless POLICIES.include?(policy)
        return [Section.finding("dmarc.policy_none", "warn")] if policy == "none"
        return [] unless POLICIES.include?(subdomain_policy) && POLICIES.index(subdomain_policy) < POLICIES.index(policy)

        [Section.finding("dmarc.weak_subdomain_policy", "warn", sp: subdomain_policy, p: policy)]
      end
    end
  end
end
