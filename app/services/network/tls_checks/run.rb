module Network
  module TlsChecks
    # Connects to a host (directly or through STARTTLS), reads its certificate and session, and checks trust, host name
    # and dates by hand, so a bad certificate is a result with findings rather than an error.
    class Run
      include Serviceable

      DEFAULT_PORTS = { "tls" => 443, "smtp" => 587, "imap" => 143, "pop3" => 110 }.freeze
      PROTOCOLS = DEFAULT_PORTS.keys.freeze
      TIMEOUT = 5
      MAX_CHAIN = 10
      EXPIRING_DAYS = 14

      def initialize(host:, port: nil, protocol: nil, environment: nil)
        @host = host
        @port = port
        @protocol = protocol.presence || "tls"
        @environment = environment
      end

      private

      def perform
        return Result.failure(error: :invalid_protocol) unless PROTOCOLS.include?(@protocol)

        target = Target.call(raw: @host, environment: @environment)
        return target if target.failure?

        raw_port = Variables.call(raw: @port, environment: @environment)
        return raw_port if raw_port.failure?

        port = number(raw_port.record)
        return Result.failure(error: :invalid_port) unless PortChecks::PortSpec::VALID.cover?(port)

        destination = Destination.call(host: target.record)
        return destination if destination.failure?

        connect(target.record, destination.record, port)
      end

      def number(value)
        text = value.to_s.strip
        text.empty? ? DEFAULT_PORTS.fetch(@protocol) : Integer(text, 10, exception: false)
      end

      def connect(host, address, port)
        sni = ip?(host) ? nil : host
        session = Tls::Handshake.call(ip: address, port:, sni:, protocol: @protocol, timeout: TIMEOUT)
        return Result.failure(error: :no_certificate) if session.chain.empty?

        Result.success(nil, host:, address:, port:, protocol: @protocol, sni:, **inspect_session(host, session))
      rescue Tls::Handshake::Refused
        Result.failure(error: :connection_refused)
      rescue Tls::Handshake::TimedOut
        Result.failure(error: :connection_timeout)
      rescue Tls::StartTls::Refused
        Result.failure(error: :starttls_refused)
      rescue Tls::Handshake::Failed => error
        Result.failure(error: :handshake_failed, detail: error.message)
      end

      def inspect_session(host, session)
        leaf = session.chain.first
        certificate = Tls::Certificate.describe(leaf)
        validity = validity(leaf)
        trust = Tls::Trust.check(session.chain)
        host_match = OpenSSL::SSL.verify_certificate_identity(leaf, host)
        details = { version: session.version, cipher: session.cipher, bits: session.bits, alpn: session.alpn }
        {
          session: details, certificate: certificate.merge(validity:, days_left: ((leaf.not_after - Time.current) / 1.day).truncate),
          chain: session.chain.first(MAX_CHAIN).map { |cert| Tls::Certificate.summarize(cert) }, trust:, host_match:,
          findings: Findings.call(certificate:, validity:, trust:, host_match:, host:, session: details)
        }
      end

      # `expiring` once less than EXPIRING_DAYS remain, or less than a third of the lifetime for short-lived
      # certificates (ACME clients renew at that point, so reaching it means renewal is failing).
      def validity(cert)
        now = Time.current
        return "not_yet_valid" if now < cert.not_before
        return "expired" if now > cert.not_after

        threshold = [EXPIRING_DAYS.days, (cert.not_after - cert.not_before) / 3].min
        cert.not_after - now < threshold ? "expiring" : "valid"
      end

      def ip?(host)
        IPAddr.new(host)
        true
      rescue IPAddr::Error
        false
      end
    end
  end
end
