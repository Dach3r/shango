module Shango
  # Where requests sent from the API Client run. `async` hands them to Solid Queue workers (the web thread returns at
  # once and the browser polls for the result), so slow targets cannot exhaust web threads; it needs a worker process
  # (`bin/jobs`, or SOLID_QUEUE_IN_PUMA=true). `inline` runs them in the web request. Default: async in production, inline elsewhere.
  module ExecutionMode
    MODES = %w[async inline].freeze

    class << self
      def async?
        mode == "async"
      end

      def mode
        value = ENV["SHANGO_EXECUTION_MODE"].presence || (Rails.env.production? ? "async" : "inline")
        MODES.include?(value) ? value : raise(ArgumentError, "SHANGO_EXECUTION_MODE must be one of #{MODES.join(", ")} (got #{value.inspect})")
      end
    end
  end
end
