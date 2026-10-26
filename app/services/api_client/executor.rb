module ApiClient
  # Performs the HTTP call described by a RequestBuilder::Built and returns a Reply.
  # Redirects are followed here (not in a Faraday middleware) so every hop goes through the SSRF
  # policy and credentials are dropped when a redirect leaves the original origin.
  class Executor
    include Serviceable

    MAX_RESPONSE_BYTES = 5.megabytes
    REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
    CREDENTIAL_HEADERS = %w[authorization proxy-authorization cookie x-api-key].freeze

    Reply = Struct.new(
      :status, :status_text, :headers, :body, :content_type, :duration_ms, :size_bytes, :truncated,
      :redirects, :final_url, :sent_headers, :error_kind, :error_message, keyword_init: true
    ) do
      def error?
        error_kind.present?
      end
    end

    Attempt = Struct.new(:status, :status_text, :headers, :body, :size, :truncated, keyword_init: true)
    TooLarge = Class.new(StandardError)

    def initialize(built:)
      @built = built
    end

    private

    def perform
      started = monotonic_now
      state = { method: @built.http_method, url: @built.url, headers: @built.headers.dup, send_body: true }
      redirects = []
      digest_tried = false

      loop do
        attempt = attempt(state)

        if challenge?(attempt) && !digest_tried && (extra = digest_headers(attempt, state))
          digest_tried = true
          state[:headers] = state[:headers].merge(extra)
          next
        end

        if redirect?(attempt, redirects)
          following = next_state(state, attempt)
          redirects << { "status" => attempt.status, "from" => state[:url], "to" => following[:url] }
          state = following
          next
        end

        return reply(attempt, state, redirects, started)
      end
    rescue StandardError => error
      error_reply(error, state, redirects, started)
    end

    def attempt(state)
      connection = Connection.build(url: state[:url], timeout: @built.timeout, verify_ssl: @built.verify_ssl, multipart: @built.body.multipart && state[:send_body])
      buffer = String.new(encoding: Encoding::BINARY)
      seen = {}
      body = state[:send_body] ? @built.body.factory.call : nil

      response = connection.run_request(state[:method].downcase.to_sym, state[:url], body, state[:headers]) do |request|
        request.options.on_data = proc do |chunk, total, env|
          seen[:status] ||= env.status
          seen[:status_text] ||= env.reason_phrase
          seen[:headers] ||= env.response_headers
          seen[:size] = total
          room = MAX_RESPONSE_BYTES - buffer.bytesize
          if chunk.bytesize > room
            buffer << chunk.byteslice(0, room)
            raise TooLarge
          end
          buffer << chunk
        end
      end

      Attempt.new(status: response.status, status_text: response.reason_phrase, headers: response.headers, body: buffer, size: buffer.bytesize, truncated: false)
    rescue TooLarge
      Attempt.new(status: seen[:status], status_text: seen[:status_text], headers: seen[:headers] || {}, body: buffer, size: MAX_RESPONSE_BYTES, truncated: true)
    end

    def challenge?(attempt)
      attempt.status == 401 && @built.auth.is_a?(Auth::Digest)
    end

    def digest_headers(attempt, state)
      @built.auth.respond_to_challenge(Struct.new(:headers).new(attempt.headers), Auth::Request.new(http_method: state[:method], url: state[:url], headers: state[:headers]))
    end

    def redirect?(attempt, redirects)
      @built.follow_redirects && REDIRECT_STATUSES.include?(attempt.status) && attempt.headers["location"].present? && redirects.size < @built.max_redirects
    end

    def next_state(state, attempt)
      target = URI.join(state[:url], attempt.headers["location"]).to_s
      switch_to_get = attempt.status == 303 || ([301, 302].include?(attempt.status) && state[:method] == "POST")
      headers = state[:headers].dup
      headers = headers.reject { |name, _| CREDENTIAL_HEADERS.include?(name.downcase) } unless same_origin?(state[:url], target)
      headers = headers.reject { |name, _| %w[content-type content-length].include?(name.downcase) } if switch_to_get

      { method: switch_to_get && state[:method] != "HEAD" ? "GET" : state[:method], url: target, headers:, send_body: state[:send_body] && !switch_to_get }
    end

    def same_origin?(first, second)
      a = URI.parse(first)
      b = URI.parse(second)
      [a.scheme, a.host, a.port] == [b.scheme, b.host, b.port]
    end

    def reply(attempt, state, redirects, started)
      Reply.new(
        status: attempt.status, status_text: attempt.status_text.presence || Rack::Utils::HTTP_STATUS_CODES[attempt.status],
        headers: attempt.headers.to_a, body: attempt.body, content_type: attempt.headers["content-type"], duration_ms: elapsed_ms(started),
        size_bytes: attempt.size, truncated: attempt.truncated, redirects:, final_url: state[:url], sent_headers: state[:headers].to_a
      )
    end

    def error_reply(error, state, redirects, started)
      kind, message = classify(error)
      Reply.new(
        headers: [], body: "", duration_ms: elapsed_ms(started), size_bytes: 0, truncated: false, redirects: redirects || [],
        final_url: state&.dig(:url) || @built.url, sent_headers: (state&.dig(:headers) || @built.headers).to_a, error_kind: kind, error_message: message
      )
    end

    def classify(error)
      case error
      when SsrfPolicy::Blocked then ["blocked", error.message]
      when Connection::InvalidUrl then ["invalid_url", error.message]
      when Faraday::TimeoutError then ["timeout", error.message]
      when Faraday::SSLError then ["ssl", error.message]
      when Faraday::ConnectionFailed then connection_failure(error)
      when SocketError then ["dns", error.message]
      else ["unknown", "#{error.class}: #{error.message}"]
      end
    end

    def connection_failure(error)
      cause = error.wrapped_exception || error.cause
      case cause
      when SocketError then ["dns", cause.message]
      when Errno::ECONNREFUSED then ["refused", cause.message]
      when Timeout::Error then ["timeout", cause.message]
      else ["connection", error.message]
      end
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(started)
      ((monotonic_now - started) * 1000).round
    end
  end
end
