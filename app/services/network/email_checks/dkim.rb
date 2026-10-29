module Network
  module EmailChecks
    # Looks up DKIM keys at `<selector>._domainkey.<domain>`. A DKIM selector cannot be discovered from outside, so the
    # ones typed after the domain are checked and reported as missing when absent; without any, a list of the
    # selectors that common mail providers use is probed and only the ones found are shown.
    class Dkim
      include Serviceable

      COMMON_SELECTORS = %w[default google selector1 selector2 k1 k2 s1 s2 mail dkim smtp mandrill zoho protonmail protonmail2 protonmail3].freeze
      MIN_BITS = 1024
      RECOMMENDED_BITS = 2048

      def initialize(domain:, selectors:)
        @domain = domain
        @selectors = selectors
      end

      private

      def perform
        probing = @selectors.empty?
        rows = Parallel.map(probing ? COMMON_SELECTORS : @selectors, limit: 8) { |selector| row(selector) }
        rows = rows.reject { |row| %w[missing unavailable].include?(row[:status]) } if probing
        findings = rows.flat_map { |row| findings(row) }
        findings << Section.finding("dkim.none_found", "warn") if probing && rows.empty?
        Section.new(data: { probed: probing, rows: }, findings:)
      end

      def row(selector)
        name = "#{selector}._domainkey.#{@domain}"
        answer = Lookup.call(name, "TXT")
        return { selector:, name:, status: "unavailable" } if Lookup.failed?(answer)

        tags = answer.answers.map { |text| Tags.parse(text) }.find { |candidate| candidate.key?("p") }
        return { selector:, name:, status: "missing" } unless tags
        return { selector:, name:, status: "revoked" } if tags["p"].blank?

        key = key(tags)
        { selector:, name:, status: key ? "found" : "invalid", key_type: (tags["k"].presence || "rsa").downcase, bits: key, testing: tags["t"].to_s.split(":").include?("y") }
      end

      # Bits of an RSA key, 0 for a key type that has no size to report, nil when the key cannot be read.
      def key(tags)
        return 0 unless (tags["k"].presence || "rsa").casecmp?("rsa")

        key = OpenSSL::PKey.read(Base64.decode64(tags["p"].delete("\s")))
        key.n.num_bits if key.is_a?(OpenSSL::PKey::RSA)
      rescue OpenSSL::PKey::PKeyError
        nil
      end

      def findings(row)
        selector = row[:selector]
        case row[:status]
        when "missing" then [Section.finding("dkim.selector_missing", "warn", selector:)]
        when "unavailable" then [Section.finding("dkim.lookup_failed", "warn", name: row[:name])]
        when "revoked" then [Section.finding("dkim.revoked", "warn", selector:)]
        when "invalid" then [Section.finding("dkim.invalid_key", "bad", selector:)]
        else key_findings(row)
        end
      end

      def key_findings(row)
        selector = row[:selector]
        bits = row[:bits]
        [
          ({ key: "dkim.weak_key", tone: bits < MIN_BITS ? "bad" : "warn", args: { selector:, bits: bits.to_s } } if bits.positive? && bits < RECOMMENDED_BITS),
          (Section.finding("dkim.testing", "warn", selector:) if row[:testing])
        ].compact
      end
    end
  end
end
