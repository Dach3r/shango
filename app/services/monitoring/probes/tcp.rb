module Monitoring
  module Probes
    # TCP monitor: one connection to host:port, closed right away (nothing is sent), like the port check of Network
    # Tools. Up when it is accepted within the timeout.
    module Tcp
      module_function

      def call(monitor)
        _host, address = Host.call(monitor)
        attempt = Network::Tcp::Probe.call(ip: address, port: monitor.port, timeout: monitor.timeout)
        case attempt.status
        when :open then Checks::Outcome.up(response_ms: attempt.ms)
        when :closed then Checks::Outcome.down(:connection_refused, response_ms: attempt.ms)
        else Checks::Outcome.down(:connection_timeout)
        end
      rescue Host::Stop => stop
        stop.outcome
      end
    end
  end
end
