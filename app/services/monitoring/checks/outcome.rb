module Monitoring
  module Checks
    # What one probe found: `up`, `down` or `unknown` (the check could not tell, e.g. a registry that did not answer),
    # with the response time, HTTP status, the cause of a failure (an i18n key under `monitoring.causes`) and its
    # masked detail, the timings of the phases, and when what it checks expires (a certificate or a domain).
    Outcome = Data.define(:status, :response_ms, :http_status, :error, :detail, :timings, :expires_at) do
      def initialize(status:, response_ms: nil, http_status: nil, error: nil, detail: nil, timings: {}, expires_at: nil)
        super
      end

      def up?
        status == "up"
      end

      def down?
        status == "down"
      end

      def self.up(**)
        new(status: "up", **)
      end

      def self.down(error, **)
        new(status: "down", error: error.to_s, **)
      end

      def self.unknown(error, **)
        new(status: "unknown", error: error.to_s, **)
      end
    end
  end
end
