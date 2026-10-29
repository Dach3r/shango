module Network
  module Tls
    # The raw exchange with one address: TCP connect, the plain-text STARTTLS dialog when asked, and a handshake that
    # accepts any certificate, so a bad one is reported by the caller instead of aborting the run. Every step shares one
    # deadline. Returns the negotiated session and the certificates the server sent, leaf first.
    class Handshake
      class TimedOut < StandardError; end
      class Refused < StandardError; end
      class Failed < StandardError; end

      Session = Data.define(:version, :cipher, :bits, :alpn, :chain)

      ALPN = %w[h2 http/1.1].freeze

      class << self
        def call(ip:, port:, sni:, protocol:, timeout:)
          deadline = now + timeout
          Socket.tcp(ip, port, connect_timeout: timeout) do |socket|
            StartTls.call(socket:, protocol:, deadline:) unless protocol == "tls"
            ssl = OpenSSL::SSL::SSLSocket.new(socket, context(alpn: protocol == "tls"))
            ssl.hostname = sni if sni
            negotiate(ssl, deadline)
            session(ssl).tap { ssl.close }
          end
        rescue Errno::ECONNREFUSED
          raise Refused
        rescue Errno::ETIMEDOUT
          raise TimedOut
        rescue OpenSSL::SSL::SSLError, SystemCallError, IOError => error
          raise Failed, error.message.split(": ").last
        end

        def wait(io, readiness, deadline)
          remaining = deadline - now
          raise TimedOut if remaining <= 0 || !io.public_send(readiness, remaining)
        end

        private

        # Old protocols and weak keys are allowed on purpose: the point is to report them, not to refuse to look.
        def context(alpn:)
          OpenSSL::SSL::SSLContext.new.tap do |context|
            context.verify_mode = OpenSSL::SSL::VERIFY_NONE
            context.min_version = OpenSSL::SSL::TLS1_VERSION
            context.security_level = 0
            context.alpn_protocols = ALPN if alpn
          end
        end

        # `connect_nonblock` answers `:wait_readable` or `:wait_writable` (the IO method to wait with) until it is done.
        def negotiate(ssl, deadline)
          while (readiness = ssl.connect_nonblock(exception: false)).is_a?(Symbol)
            wait(ssl.to_io, readiness, deadline)
          end
        end

        def session(ssl)
          name, _protocol, bits = ssl.cipher
          Session.new(version: ssl.ssl_version, cipher: name, bits:, alpn: ssl.alpn_protocol, chain: ssl.peer_cert_chain.to_a)
        end

        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
