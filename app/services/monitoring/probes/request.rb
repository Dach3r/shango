module Monitoring
  module Probes
    # HTTP monitor of a saved API Client request: the saved request (never a draft) built with the monitor's
    # environment and no user, so secret variables and auth work as in the API Client but `{{$response…}}` references
    # do not resolve. Executed with the monitor's timeout as the deadline of the whole run, 64 KB of body read and
    # discarded, and every hop pinned to an address that passed the outbound guard and is never a cloud metadata
    # address. Up under the same rules as a URL monitor. Every text kept (error detail) goes through the masker.
    module Request
      BODY_LIMIT = 64.kilobytes
      ERRORS = {
        "blocked" => :blocked, "invalid_url" => :invalid_url, "timeout" => :connection_timeout, "ssl" => :tls_failed, "dns" => :unresolved,
        "refused" => :connection_refused, "connection" => :connection_failed
      }.freeze
      RESOLVE = lambda do |host|
        result = Network::Destination.call(host:)
        raise Network::SsrfPolicy::Blocked, result.data[:detail] || host if result.failure? && result.error == :blocked
        raise SocketError, "#{host} does not resolve" if result.failure?
        raise Network::SsrfPolicy::Blocked, "#{host} resolves to a cloud metadata address (#{result.record})" if Guard.metadata?(result.record)

        result.record
      end

      module_function

      def call(monitor)
        return Checks::Outcome.down(:environment_missing) if monitor.environment_required && !monitor.environment
        return Checks::Outcome.down(:request_missing) unless monitor.api_request

        built = ApiClient::RequestBuilder.call(api_request: monitor.api_request, environment: monitor.environment)
        return unbuilt(monitor, built) if built.failure?
        return Checks::Outcome.down(:unresolved_variable, detail: built.record.unresolved.join(", ").first(255)) if built.record.unresolved.any?

        run(monitor, built.record)
      end

      def unbuilt(monitor, built)
        return Checks::Outcome.down(:unresolved_variable, detail: built.data[:unresolved].join(", ").first(255)) if built.data[:unresolved].present?

        masker = ApiClient::Masker.new(monitor.environment&.secret_values || [])
        Checks::Outcome.down(built.data[:auth] ? :auth_failed : :invalid_request, detail: masker.string(built.error.to_s).first(255))
      end

      def run(monitor, built)
        masker = ApiClient::Masker.new(built.secrets)
        reply = ApiClient::Executor.call(built:, deadline: monitor.timeout, max_bytes: BODY_LIMIT, resolve: RESOLVE)
        ms = reply.duration_ms
        timings = reply.timings.slice("dns", "tcp", "tls", "ttfb")
        return Checks::Outcome.down(ERRORS.fetch(reply.error_kind, :connection_failed), detail: masker.string(reply.error_message).to_s.first(255), response_ms: ms, timings:) if reply.error?

        status = reply.status
        return Checks::Outcome.down(:unexpected_status, http_status: status, response_ms: ms, detail: masker.string("#{status} #{reply.status_text}".strip).first(255), timings:) unless Http.expected?(monitor, status)

        limit = monitor.max_response_ms
        return Checks::Outcome.down(:slow_response, http_status: status, response_ms: ms, detail: "#{ms} ms > #{limit} ms", timings:) if limit && ms > limit

        Checks::Outcome.up(http_status: status, response_ms: ms, timings:)
      end
    end
  end
end
