module Network
  module EmailChecks
    # Checks how a domain is set up to send and receive mail, from its DNS alone: SPF (with the lookups it costs),
    # DKIM (the selectors typed after the domain, or the common ones), DMARC and MX. The result is each part's data and
    # one list of findings, worst first.
    class Run
      include Serviceable

      MAX_SELECTORS = 10
      SELECTOR = /\A[a-z0-9_]([a-z0-9_.-]{0,61}[a-z0-9_])?\z/

      def initialize(domain:, selectors: nil, environment: nil)
        @domain = domain
        @selectors = selectors
        @environment = environment
      end

      private

      def perform
        target = Target.call(raw: @domain, environment: @environment)
        return target if target.failure?

        host = target.record
        return Result.failure(error: :domain_needed) if ip?(host)

        selectors = parse_selectors
        return selectors if selectors.failure?

        txt = Lookup.call(host, "TXT")
        return Result.failure(error: :domain_not_found) if txt.status == :nxdomain

        spf, dkim, dmarc, mx = Parallel.map(sections(host, txt, selectors.record), limit: 4, &:call)
        findings = [spf, dkim, dmarc, mx].flat_map(&:findings)
        Result.success(nil, host:, spf: spf.data, dkim: dkim.data, dmarc: dmarc.data, mx: mx.data,
                            findings: findings.sort_by.with_index { |finding, index| [finding[:tone] == "bad" ? 0 : 1, index] })
      end

      def sections(host, txt, selectors)
        [-> { Spf.call(domain: host, answer: txt) }, -> { Dkim.call(domain: host, selectors:) }, -> { Dmarc.call(domain: host) }, -> { Mx.call(domain: host) }]
      end

      def parse_selectors
        raw = Variables.call(raw: @selectors, environment: @environment)
        return raw if raw.failure?

        list = raw.record.downcase.split.uniq
        return Result.failure(error: :too_many_selectors, max: MAX_SELECTORS) if list.size > MAX_SELECTORS

        invalid = list.find { |selector| !selector.match?(SELECTOR) }
        invalid ? Result.failure(error: :invalid_selector, token: invalid) : Result.success(list)
      end

      def ip?(host)
        IPAddr.new(host)
        true
      rescue IPAddr::Error
        false
      end
    end
  end
end
