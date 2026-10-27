module Network
  module Dns
    # One DNS exchange with one nameserver, as raw bytes: `udp` for the normal case, `tcp` for answers that
    # come back truncated. Sockets are opened per call and closed before returning.
    class Transport
      class TimedOut < StandardError; end
      class Failed < StandardError; end

      PORT = 53
      MAX_UDP_REPLY = 4096

      class << self
        def udp(ip:, payload:, timeout:, port: PORT)
          address = Addrinfo.udp(ip, port)
          socket = Socket.new(address.afamily, :DGRAM)
          begin
            socket.connect(address)
            socket.send(payload, 0)
            raise TimedOut unless socket.wait_readable(timeout)

            socket.recv(MAX_UDP_REPLY)
          ensure
            socket.close
          end
        rescue SystemCallError => error
          raise Failed, error.message
        end

        def tcp(ip:, payload:, timeout:, port: PORT)
          deadline = now + timeout
          Socket.tcp(ip, port, connect_timeout: timeout) do |socket|
            socket.write([payload.bytesize].pack("n") + payload)
            length = read(socket, 2, deadline).unpack1("n")
            read(socket, length, deadline)
          end
        rescue Errno::ETIMEDOUT
          raise TimedOut
        rescue SystemCallError, EOFError => error
          raise Failed, error.message
        end

        private

        def read(socket, length, deadline)
          data = +""
          while data.bytesize < length
            remaining = deadline - now
            raise TimedOut if remaining <= 0 || !socket.wait_readable(remaining)

            data << socket.readpartial(length - data.bytesize)
          end
          data
        end

        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
