module Monitoring
  module Probes
    # HTTP monitor of a typed URL: GET or HEAD with `{{variables}}` from the monitor's environment (secret ones are
    # refused), redirects followed by hand, every hop through the outbound guard and pinned to the checked address, no
    # proxy. Only the status line and the headers are read, never the body. Up when the final status is one of the
    # expected ones and the whole run fits the response-time limit; one deadline (the timeout) covers every hop.
    class Http
      MAX_REDIRECTS = 10
      REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
      HEADERS = { "User-Agent" => "Shango monitor", "Accept" => "*/*" }.freeze
      REQUESTS = { "GET" => Net::HTTP::Get, "HEAD" => Net::HTTP::Head }.freeze
      SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i

      class Stop < StandardError
        attr_reader :error, :detail

        def initialize(error, detail = nil)
          @error = error
          @detail = detail
          super(error.to_s)
        end
      end

      # A monitor of a saved request is checked by Probes::Request.
      def self.call(monitor)
        monitor.mode == "request" ? Request.call(monitor) : new(monitor).call
      end

      # Whether a status is one of the monitor's expected ones ("200-399", "200,301-302").
      def self.expected?(monitor, status)
        monitor.expected_statuses.to_s.split(",").any? do |part|
          first, last = part.split("-").map(&:to_i)
          (first..(last || first)).cover?(status)
        end
      end

      def initialize(monitor)
        @monitor = monitor
      end

      def call
        return Checks::Outcome.down(:environment_missing) if @monitor.environment_required && !@monitor.environment

        resolved = Network::Variables.call(raw: @monitor.url, environment: @monitor.environment)
        return Checks::Outcome.down(resolved.error, detail: resolved.data[:name]) if resolved.failure?

        uri = url(resolved.record.strip) || (return Checks::Outcome.down(:invalid_url))
        @deadline = now + @monitor.timeout
        started = now
        status, reason, timings = follow(uri)
        evaluate(status, reason, timings, ((now - started) * 1000).round)
      rescue Stop => stop
        Checks::Outcome.down(stop.error, detail: stop.detail)
      end

      private

      def follow(uri)
        seen = Set.new
        (MAX_REDIRECTS + 1).times do
          seen << uri.to_s
          status, reason, location, timings = request(uri)
          return [status, reason, timings] unless REDIRECT_STATUSES.include?(status) && location.present?

          uri = url(location, uri) || raise(Stop.new(:invalid_redirect, location.first(255)))
          raise Stop.new(:redirect_loop, uri.to_s.first(255)) if seen.include?(uri.to_s)
        end
        raise Stop, :too_many_redirects
      end

      def evaluate(status, reason, timings, ms)
        return Checks::Outcome.down(:unexpected_status, http_status: status, response_ms: ms, detail: "#{status} #{reason}".strip, timings:) unless self.class.expected?(@monitor, status)

        limit = @monitor.max_response_ms
        return Checks::Outcome.down(:slow_response, http_status: status, response_ms: ms, detail: "#{ms} ms > #{limit} ms", timings:) if limit && ms > limit

        Checks::Outcome.up(http_status: status, response_ms: ms, timings:)
      end

      # One hop: the status, reason, location and phase timings of the answer.
      def request(uri)
        timeout = @deadline - now
        raise Stop, :connection_timeout unless timeout.positive?

        timing = ApiClient::Timing.new
        address = timing.measure(:dns) { destination(uri.hostname) }
        http = Net::HTTP.new(uri.hostname, uri.port, nil)
        http.ipaddr = address
        http.use_ssl = uri.is_a?(URI::HTTPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = http.read_timeout = http.write_timeout = timeout
        timing.probe(http)
        timing.begin_attempt
        started = now
        http.start do
          http.request(REQUESTS.fetch(@monitor.http_method).new(uri, HEADERS)) do |response|
            timing.first_byte!
            timing.end_attempt
            phases = timing.to_h(((now - started) * 1000).round).slice("dns", "tcp", "tls", "ttfb")
            return [response.code.to_i, response.message.to_s.scrub.strip.first(100), response["location"].to_s.scrub.strip, phases]
          end
        end
      rescue Errno::ECONNREFUSED
        raise Stop, :connection_refused
      rescue Timeout::Error, Errno::ETIMEDOUT
        raise Stop, :connection_timeout
      rescue OpenSSL::SSL::SSLError => error
        raise Stop.new(:tls_failed, error.message.split("state=error: ").last.scrub.first(255))
      rescue SystemCallError, IOError, SocketError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => error
        raise Stop.new(:connection_failed, error.message.scrub.first(255))
      end

      def destination(host)
        result = Network::Destination.call(host:)
        raise Stop.new(result.error, result.data[:detail]) if result.failure?
        raise Stop.new(:blocked, "#{host} resolves to a cloud metadata address (#{result.record})") if Guard.metadata?(result.record)

        result.record
      end

      # An http(s) URL with a host and without user info or fragment, or nil.
      def url(text, base = nil)
        return if text.length > UptimeMonitor::MAX_URL_LENGTH || text.match?(/\s/)

        uri = base ? URI.join(base, text) : URI.parse(text.match?(SCHEME) ? text : "https://#{text}")
        return unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?

        uri.fragment = nil
        uri
      rescue URI::Error
        nil
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
