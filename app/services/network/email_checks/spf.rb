module Network
  module EmailChecks
    # Reads the SPF record of a domain and follows its `include` and `redirect` terms the way a receiver does, to count
    # the DNS lookups it costs (a receiver gives up past ten) and to find what the record ends with.
    class Spf
      include Serviceable

      LOOKUP_LIMIT = 10
      GIVE_UP = LOOKUP_LIMIT * 2
      MAX_DEPTH = 10
      VERSION = /\Av=spf1(\s|\z)/i
      LOOKUP_TERMS = %w[include a mx ptr exists redirect].freeze
      REFERENCES = %w[include redirect].freeze
      Term = Data.define(:qualifier, :name, :value)

      def initialize(domain:, answer:)
        @domain = domain
        @answer = answer
        @lookups = 0
        @cache = {}
        @missing = []
        @unavailable = []
        @loops = []
        @ptr = false
      end

      private

      def perform
        return Section.new(data: nil, findings: [Section.finding("spf.lookup_failed", "warn", name: @domain)]) if Lookup.failed?(@answer)

        records = spf_records(@answer)
        return Section.new(data: nil, findings: [Section.finding("spf.missing", "bad")]) if records.empty?

        qualifier = walk(@domain, records.first, [])
        data = { record: records.first, lookups: @lookups, all: qualifier && "#{qualifier}all" }
        Section.new(data:, findings: [(Section.finding("spf.multiple", "bad") if records.size > 1), *findings(qualifier)].compact)
      end

      def spf_records(answer)
        answer.status == :ok ? answer.answers.select { |text| text.match?(VERSION) } : []
      end

      # The qualifier of the `all` term the record ends with, taken from the redirect target when it has none.
      def walk(domain, record, chain)
        terms = record.split.drop(1).map { |token| parse(token) }
        @lookups += terms.count { |term| LOOKUP_TERMS.include?(term.name) }
        @ptr ||= terms.any? { |term| term.name == "ptr" }
        references = terms.select { |term| REFERENCES.include?(term.name) && term.value.present? }.first(GIVE_UP)
        targets = references.map { |term| term.value.downcase.delete_suffix(".") }
        prefetch(targets)
        redirected = nil
        references.zip(targets).each do |term, target|
          qualifier = follow(target, chain + [domain])
          redirected = qualifier if term.name == "redirect"
        end
        own = terms.find { |term| term.name == "all" }
        own ? (own.qualifier.presence || "+") : redirected
      end

      def parse(token)
        qualifier = token[/\A[+\-~?]/]
        name, value = token.delete_prefix(qualifier.to_s).split(/[:=]/, 2)
        Term.new(qualifier:, name: name.split("/", 2).first.to_s.downcase, value: value&.sub(%r{/\d+(//\d+)?\z}, ""))
      end

      # Macros (`%{d}`) depend on the sender, so those terms count as lookups but are not followed.
      def follow(target, chain)
        return if target.include?("%") || @lookups > GIVE_UP || chain.size >= MAX_DEPTH
        return flag(@loops, target) if chain.include?(target)
        return flag(@missing, target) unless Lookup.name?(target)

        answer = fetch(target)
        return flag(@unavailable, target) if Lookup.failed?(answer)

        record = spf_records(answer).first
        record ? walk(target, record, chain) : flag(@missing, target)
      end

      def flag(list, target)
        list << target
        nil
      end

      def prefetch(names)
        return if @lookups > GIVE_UP

        pending = names.uniq.select { |name| Lookup.name?(name) && !@cache.key?(name) }
        Parallel.map(pending, limit: 5) { |name| [name, Lookup.call(name, "TXT")] }.each { |name, answer| @cache[name] = answer }
      end

      def fetch(name)
        @cache[name] ||= Lookup.call(name, "TXT")
      end

      def findings(qualifier)
        [
          ({ key: "spf.too_many_lookups", tone: "bad", args: { count: @lookups, limit: LOOKUP_LIMIT } } if @lookups > LOOKUP_LIMIT),
          *@loops.uniq.map { |name| Section.finding("spf.loop", "bad", name:) },
          *@missing.uniq.map { |name| Section.finding("spf.include_missing", "bad", name:) },
          *@unavailable.uniq.map { |name| Section.finding("spf.lookup_failed", "warn", name:) },
          *all_finding(qualifier),
          (Section.finding("spf.ptr", "warn") if @ptr)
        ].compact
      end

      def all_finding(qualifier)
        case qualifier
        when nil then [Section.finding("spf.no_all", "warn")]
        when "+" then [Section.finding("spf.pass_all", "bad")]
        when "?" then [Section.finding("spf.neutral_all", "warn")]
        else []
        end
      end
    end
  end
end
