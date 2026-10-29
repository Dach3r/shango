module Monitoring
  module Probes
    # Domain monitor: the registration of a domain through RDAP (`Network::Lookups::Domain`, which also finds the
    # registered domain of a subdomain), never touching the host itself. Down when the domain is not registered,
    # expired, on hold, pending delete, or expires in fewer than `days_before` days. A registry that does not answer,
    # has no RDAP service or gives no expiry date is `unknown`, never down. Keeps the expiry date on the outcome.
    module Domain
      DAY = 86_400
      UNKNOWN = { no_rdap_service: :no_rdap_service, rdap_unavailable: :rdap_unavailable, unavailable: :rdap_unavailable }.freeze

      module_function

      def call(monitor, now: Time.current)
        host = Host.name(monitor)
        return Checks::Outcome.down(:invalid_host) if Ssl.ip?(host)

        started = clock
        result = Network::Lookups::Domain.call(host:, deadline: started + monitor.timeout)
        ms = ((clock - started) * 1000).round
        return failed(result.error, ms) if result.failure?

        judge(monitor, result.data[:domain], ms, now)
      rescue Host::Stop => stop
        stop.outcome
      end

      def failed(error, ms)
        return Checks::Outcome.down(:domain_not_registered, response_ms: ms) if error == :not_registered

        Checks::Outcome.unknown(UNKNOWN.fetch(error, :rdap_unavailable), response_ms: ms)
      end

      def judge(monitor, domain, ms, now)
        flags = domain[:statuses].map { |status| status.downcase.delete(" ") }
        expires_at = domain[:expires] && Time.zone.parse(domain[:expires])
        problem = problem(monitor, flags, expires_at, now)
        return Checks::Outcome.unknown(:no_expiry, response_ms: ms) if problem == :no_expiry
        return Checks::Outcome.down(problem, detail: expires_at&.utc&.to_date&.iso8601, response_ms: ms, expires_at:) if problem

        Checks::Outcome.up(response_ms: ms, expires_at:)
      end

      def problem(monitor, flags, expires_at, now)
        return :domain_on_hold if flags.intersect?(Network::Lookups::Domain::HOLDS)
        return :domain_pending_delete if flags.intersect?(Network::Lookups::Domain::PENDING)
        return :no_expiry unless expires_at
        return :domain_expired if expires_at <= now

        :domain_expiring if ((expires_at - now) / DAY).floor < monitor.days_before
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
