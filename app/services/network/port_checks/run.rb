module Network
  module PortChecks
    class Run
      include Serviceable

      TIMEOUT = 1.5
      CONCURRENCY = 20
      STATUSES = %i[open closed filtered].freeze

      def initialize(host:, ports:, environment: nil)
        @host = host
        @ports = ports
        @environment = environment
      end

      private

      def perform
        target = Target.call(raw: @host, environment: @environment)
        return target if target.failure?

        raw_ports = Variables.call(raw: @ports, environment: @environment)
        return raw_ports if raw_ports.failure?

        ports = PortSpec.call(raw: raw_ports.record)
        return ports if ports.failure?

        destination = Destination.call(host: target.record)
        return destination if destination.failure?

        rows = Parallel.map(ports.record, limit: CONCURRENCY) { |port| probe(destination.record, port) }
        rows = rows.sort_by { |row| [row.status == :open ? 0 : 1, row.port] }
        Result.success(nil, host: target.record, address: destination.record, rows:, counts: STATUSES.to_h { |status| [status, rows.count { |row| row.status == status }] })
      end

      def probe(address, port)
        attempt = Tcp::Probe.call(ip: address, port:, timeout: TIMEOUT)
        Row.new(port:, service: Services.name(port), status: attempt.status, ms: attempt.ms)
      end
    end
  end
end
