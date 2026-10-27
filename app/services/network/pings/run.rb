module Network
  module Pings
    # "Is it online?": connects to a TCP port several times in a row and reports latency and loss. It is a TCP ping,
    # not ICMP (that needs raw sockets). A refused connection still counts as an answer: the host is up, nothing
    # listens on that port. Stops early after MAX_CONSECUTIVE_TIMEOUTS timeouts in a row so a dead host does not
    # hold the request for the full run.
    class Run
      include Serviceable

      DEFAULT_PORT = 443
      DEFAULT_ATTEMPTS = 4
      MAX_ATTEMPTS = 10
      TIMEOUT = 2
      MAX_CONSECUTIVE_TIMEOUTS = 5

      def initialize(host:, port: nil, attempts: nil, environment: nil)
        @host = host
        @port = port
        @attempts = attempts
        @environment = environment
      end

      private

      def perform
        target = Target.call(raw: @host, environment: @environment)
        return target if target.failure?

        raw_port = Variables.call(raw: @port, environment: @environment)
        return raw_port if raw_port.failure?

        raw_attempts = Variables.call(raw: @attempts, environment: @environment)
        return raw_attempts if raw_attempts.failure?

        port = number(raw_port.record, DEFAULT_PORT)
        return Result.failure(error: :invalid_port) unless PortChecks::PortSpec::VALID.cover?(port)

        count = number(raw_attempts.record, DEFAULT_ATTEMPTS)
        return Result.failure(error: :invalid_attempts, max: MAX_ATTEMPTS) unless (1..MAX_ATTEMPTS).cover?(count)

        destination = Destination.call(host: target.record)
        return destination if destination.failure?

        attempts = probe(destination.record, port, count)
        Result.success(nil, host: target.record, address: destination.record, port:, attempts:, summary: summarize(attempts, count))
      end

      # Whole numbers only; blank means the default and anything else is returned as nil so validation rejects it.
      def number(value, default)
        text = value.to_s.strip
        return default if text.empty?

        Integer(text, 10, exception: false)
      end

      def probe(address, port, count)
        attempts = []
        timeouts = 0
        count.times do
          attempt = Tcp::Probe.call(ip: address, port:, timeout: TIMEOUT)
          attempts << attempt
          timeouts = attempt.status == :filtered ? timeouts + 1 : 0
          break if timeouts >= MAX_CONSECUTIVE_TIMEOUTS
        end
        attempts
      end

      def summarize(attempts, planned)
        answered = attempts.reject { |attempt| attempt.status == :filtered }
        times = answered.map(&:ms)
        {
          sent: attempts.size, received: answered.size, loss: ((attempts.size - answered.size) * 100.0 / attempts.size).round,
          min: times.min, max: times.max, avg: times.empty? ? nil : (times.sum.to_f / times.size).round,
          open: answered.count { |attempt| attempt.status == :open }, stopped: attempts.size < planned
        }
      end
    end
  end
end
