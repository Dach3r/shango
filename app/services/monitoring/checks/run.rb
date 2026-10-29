module Monitoring
  module Checks
    # Runs the probe of a monitor's kind and returns its Outcome. A kind without a probe yet is `unknown`, so it never
    # opens an incident.
    module Run
      PROBES = {}.freeze

      module_function

      def call(monitor)
        probe = PROBES[monitor.kind]
        probe ? probe.call(monitor) : Outcome.unknown(:unsupported_kind)
      end

      def kinds
        PROBES.keys
      end
    end
  end
end
