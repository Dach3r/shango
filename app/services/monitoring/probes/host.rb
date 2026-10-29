module Monitoring
  module Probes
    # The host of a TCP, SSL or domain monitor, its `{{variables}}` resolved from the monitor's environment (secret
    # ones are refused), and the address to connect to: through the outbound guard and never a cloud metadata address.
    # `call` returns `[host, address]` and `name` the host alone; both raise Stop with the cause.
    module Host
      class Stop < StandardError
        attr_reader :outcome

        def initialize(outcome)
          @outcome = outcome
          super(outcome.error)
        end
      end

      module_function

      def call(monitor)
        host = name(monitor)
        [host, address(host)]
      end

      def name(monitor)
        stop(:environment_missing) if monitor.environment_required && !monitor.environment
        target = Network::Target.call(raw: monitor.host, environment: monitor.environment)
        stop(target.error == :blank || target.error == :invalid ? :invalid_host : target.error, detail: target.data[:name]) if target.failure?

        target.record
      end

      def address(host)
        result = Network::Destination.call(host:)
        stop(result.error, detail: result.data[:detail]) if result.failure?
        stop(:blocked, detail: "#{host} resolves to a cloud metadata address (#{result.record})") if Guard.metadata?(result.record)

        result.record
      end

      def stop(error, **)
        raise Stop, Checks::Outcome.down(error, **)
      end
    end
  end
end
