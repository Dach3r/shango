module Monitoring
  module Probes
    # SSL monitor: a TLS handshake with host:port (SNI with the host name), then the certificate it sent. Down when
    # there is none, it does not chain to a trusted root, it is not valid for the host, it is not valid yet or any
    # more, or it expires in fewer than `days_before` days. Keeps the expiry date on the outcome.
    module Ssl
      DAY = 86_400

      module_function

      def call(monitor, now: Time.current)
        host, address = Host.call(monitor)
        started = clock
        session = Network::Tls::Handshake.call(ip: address, port: monitor.port, sni: ip?(host) ? nil : host, protocol: "tls", timeout: monitor.timeout)
        judge(monitor, host, session.chain, ((clock - started) * 1000).round, now)
      rescue Host::Stop => stop
        stop.outcome
      rescue Network::Tls::Handshake::Refused
        Checks::Outcome.down(:connection_refused)
      rescue Network::Tls::Handshake::TimedOut
        Checks::Outcome.down(:connection_timeout)
      rescue Network::Tls::Handshake::Failed => error
        Checks::Outcome.down(:tls_failed, detail: error.message.to_s.scrub.first(255))
      end

      def judge(monitor, host, chain, ms, now)
        leaf = chain.first
        return Checks::Outcome.down(:no_certificate, response_ms: ms) unless leaf

        expires_at = leaf.not_after.utc
        failure = problem(monitor, host, chain, leaf, now)
        return Checks::Outcome.down(failure.first, detail: failure.last, response_ms: ms, expires_at:) if failure

        Checks::Outcome.up(response_ms: ms, expires_at:)
      end

      # The first thing wrong with the certificate, as [cause, detail], or nil.
      def problem(monitor, host, chain, leaf, now)
        trust = Network::Tls::Trust.check(chain)
        return [:untrusted_certificate, trust[:reason]] unless trust[:status] == "trusted"
        return [:hostname_mismatch, Network::Tls::Certificate.entity(leaf.subject)[:name].to_s.first(255)] unless OpenSSL::SSL.verify_certificate_identity(leaf, host)
        return [:certificate_not_yet_valid, leaf.not_before.utc.iso8601] if leaf.not_before > now
        return [:certificate_expired, leaf.not_after.utc.iso8601] if leaf.not_after <= now

        days = ((leaf.not_after - now) / DAY).floor
        [:certificate_expiring, leaf.not_after.utc.to_date.iso8601] if days < monitor.days_before
      end

      def ip?(host)
        IPAddr.new(host)
        true
      rescue IPAddr::Error
        false
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
