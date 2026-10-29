module Network
  module Rdap
    # One JSON document over HTTPS from an RDAP or IANA bootstrap server. Every hop, redirects included, goes through
    # the outbound guard and connects to the address that was checked. A run of requests shares one deadline, and
    # nothing is read past MAX_BYTES. Returns a Result: the parsed hash, or `not_found` / `unavailable`.
    class Client
      include Serviceable

      class Failed < StandardError; end

      TIMEOUT = 5
      MAX_BYTES = 1.megabyte
      MAX_REDIRECTS = 3
      HEADERS = { "Accept" => "application/rdap+json, application/json", "User-Agent" => "Shango network tools" }.freeze

      def initialize(url:, deadline: nil)
        @url = url
        @deadline = deadline || now + TIMEOUT
      end

      private

      def perform
        uri = URI.parse(@url)
        (MAX_REDIRECTS + 1).times do
          response, body = fetch(uri)
          case response
          when Net::HTTPSuccess then return parse(body)
          when Net::HTTPNotFound then return Result.failure(error: :not_found)
          when Net::HTTPRedirection then uri = URI.join(uri, response["location"].to_s)
          else raise Failed
          end
        end
        raise Failed
      rescue Failed, Network::SsrfPolicy::Blocked, URI::Error, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, EOFError, JSON::ParserError
        Result.failure(error: :unavailable)
      end

      def fetch(uri)
        raise Failed unless uri.is_a?(URI::HTTPS) && uri.hostname.present?

        limit = [now + TIMEOUT, @deadline].min
        timeout = limit - now
        raise Failed unless timeout.positive?

        address = Network::SsrfPolicy.check!(uri.hostname)
        options = { use_ssl: true, open_timeout: timeout, read_timeout: timeout, write_timeout: timeout, verify_mode: OpenSSL::SSL::VERIFY_PEER }
        options[:ipaddr] = address if address
        Net::HTTP.start(uri.hostname, uri.port, **options) do |http|
          http.request(Net::HTTP::Get.new(uri, HEADERS)) { |response| return [response, (read(response, limit) if response.is_a?(Net::HTTPSuccess))] }
        end
      end

      def read(response, limit)
        body = +""
        response.read_body do |chunk|
          body << chunk
          raise Failed if body.bytesize > MAX_BYTES || now > limit
        end
        body
      end

      def parse(body)
        json = JSON.parse(body)
        raise Failed unless json.is_a?(Hash)

        Result.success(json)
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
