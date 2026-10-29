module Network
  module EmailChecks
    # What one part of the check (SPF, DKIM, DMARC, MX) found: its data, and its findings, each a locale key under
    # `network.email.findings`, a tone (`bad` breaks delivery or protection, `warn` should be fixed) and the values its text needs.
    Section = Data.define(:data, :findings) do
      def self.finding(key, tone, **args)
        { key:, tone:, args: }
      end
    end
  end
end
