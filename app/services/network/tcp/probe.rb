module Network
  module Tcp
    # One TCP connection attempt to an address, closed right away: no data is ever sent or read.
    # `open` accepted the connection, `closed` refused it (the host answered, nothing listens), `filtered` gave no
    # answer in time or could not be reached (typically a firewall dropping packets).
    class Probe
      include Serviceable

      Attempt = Data.define(:status, :ms)

      def initialize(ip:, port:, timeout:)
        @ip = ip
        @port = port
        @timeout = timeout
      end

      private

      def perform
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Socket.tcp(@ip, @port, connect_timeout: @timeout) { nil }
        attempt(:open, started)
      rescue Errno::ECONNREFUSED
        attempt(:closed, started)
      rescue SystemCallError
        attempt(:filtered, started)
      end

      def attempt(status, started)
        Attempt.new(status:, ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
      end
    end
  end
end
