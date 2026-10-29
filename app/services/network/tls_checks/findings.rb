module Network
  module TlsChecks
    # What is wrong with a certificate and its session, worst first. Each finding is a locale key under
    # `network.tls.findings`, a tone (`bad` breaks clients, `warn` should be fixed) and the values its text needs.
    module Findings
      OLD_PROTOCOLS = %w[SSLv3 TLSv1 TLSv1.1].freeze
      MIN_KEY_BITS = { "RSA" => 2048, "EC" => 224 }.freeze
      WEAK_SIGNATURE = /md2|md5|sha1/i

      module_function

      def call(certificate:, validity:, trust:, host_match:, host:, session:)
        [
          *dates(certificate, validity),
          ({ key: "name_mismatch", tone: "bad", args: { host: } } unless host_match),
          ({ key: "untrusted.#{trust[:reason]}", tone: "bad", args: trust[:reason] == "other" ? { code: trust[:code].to_s } : {} } if trust[:status] == "untrusted"),
          ({ key: "old_protocol", tone: "warn", args: { version: session[:version] } } if OLD_PROTOCOLS.include?(session[:version])),
          weak_key(certificate[:key]),
          ({ key: "weak_signature", tone: "warn", args: { algorithm: certificate[:signature] } } if certificate[:signature].match?(WEAK_SIGNATURE))
        ].compact.sort_by { |finding| finding[:tone] == "bad" ? 0 : 1 }
      end

      def dates(certificate, validity)
        case validity
        when "expired" then [{ key: "expired", tone: "bad", args: { date: certificate[:not_after].first(10) } }]
        when "not_yet_valid" then [{ key: "not_yet_valid", tone: "bad", args: { date: certificate[:not_before].first(10) } }]
        when "expiring" then [{ key: "expiring", tone: "warn", args: { date: certificate[:not_after].first(10) } }]
        else []
        end
      end

      def weak_key(key)
        minimum = MIN_KEY_BITS[key[:type]]
        return unless minimum && key[:bits] < minimum

        { key: "weak_key", tone: "warn", args: { type: key[:type], bits: key[:bits].to_s } }
      end
    end
  end
end
