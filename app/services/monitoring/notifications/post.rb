module Monitoring
  module Notifications
    # POSTs a JSON body to a channel URL: through the outbound guard, pinned to the checked address, never to a cloud
    # metadata address, no proxy, no redirects, 10 seconds. Only the status of the answer is read. The URL is never
    # put in an error, since it often is the credential.
    class Post
      include Serviceable

      TIMEOUT = 10
      HEADERS = { "Content-Type" => "application/json", "User-Agent" => "Shango notifications" }.freeze

      def initialize(uri:, body:, headers: {})
        @uri = uri
        @body = body
        @headers = headers
      end

      private

      def perform
        return Result.failure(error: :invalid_url, permanent: true) unless @uri.is_a?(URI::HTTP) && @uri.host.present? && @uri.userinfo.nil?

        address, refusal = destination
        refusal || answer(send_post(address))
      rescue Errno::ECONNREFUSED
        Result.failure(error: :connection_refused)
      rescue Timeout::Error, Errno::ETIMEDOUT
        Result.failure(error: :connection_timeout)
      rescue OpenSSL::SSL::SSLError => error
        Result.failure(error: :tls_failed, detail: error.message.split("state=error: ").last.scrub.first(255))
      rescue SystemCallError, IOError, SocketError, Net::HTTPBadResponse, Net::ProtocolError => error
        Result.failure(error: :connection_failed, detail: error.class.name)
      end

      # The checked address, or the failure that refuses it.
      def destination
        result = Network::Destination.call(host: @uri.hostname)
        return [nil, Result.failure(error: result.error, permanent: result.error == :blocked)] if result.failure?
        return [nil, Result.failure(error: :blocked, permanent: true)] if Guard.metadata?(result.record)

        [result.record, nil]
      end

      def send_post(address)
        http = Net::HTTP.new(@uri.hostname, @uri.port, nil)
        http.ipaddr = address
        http.use_ssl = @uri.is_a?(URI::HTTPS)
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = http.read_timeout = http.write_timeout = TIMEOUT
        request = Net::HTTP::Post.new(@uri, HEADERS.merge(@headers))
        request.body = @body
        http.start { http.request(request) }
      end

      def answer(response)
        status = response.code.to_i
        return Result.success(status:) if (200..299).cover?(status)
        return Result.failure(error: :rate_limited, detail: status.to_s, retry_after: response["retry-after"].to_f.ceil) if status == 429

        Result.failure(error: :unexpected_status, detail: status.to_s, permanent: (400..499).cover?(status) && status != 408)
      end
    end
  end
end
