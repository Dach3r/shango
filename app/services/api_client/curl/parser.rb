module ApiClient
  module Curl
    # Converts a `curl ...` command into ApiRequest attributes (Result#record is the attributes hash).
    class Parser
      include Serviceable

      WITH_ARGUMENT = %w[
        -X --request -H --header -d --data --data-raw --data-binary --data-ascii --data-urlencode --json -F --form
        -u --user -A --user-agent -e --referer -b --cookie -o --output -m --max-time --connect-timeout -w --write-out
        -x --proxy -T --upload-file --url --cacert --cert --key -K --config --retry -E --max-redirs
      ].freeze
      SHORT_WITH_ARGUMENT = %w[X H d F u A e b o m w x T K E].freeze
      BODY_FLAGS = %w[-d --data --data-raw --data-binary --data-ascii --data-urlencode --json].freeze

      class Invalid < StandardError; end

      def initialize(command:)
        @command = command.to_s
        @headers = []
        @data = []
        @form = []
        @method = nil
        @url = nil
        @user = nil
        @insecure = false
        @location = false
        @get = false
        @head = false
        @timeout = nil
        @json = false
      end

      private

      def perform
        tokens = tokenize
        raise Invalid, I18n.t("workbench.curl.empty") if tokens.empty?

        parse(tokens)
        raise Invalid, I18n.t("workbench.curl.missing_url") if @url.blank?

        Result.success(attributes)
      rescue Invalid, ArgumentError => error
        Result.failure(error: error.message)
      end

      def tokenize
        tokens = Shellwords.split(@command.gsub(/\\\r?\n/, " ").strip)
        tokens.shift if tokens.first == "curl"
        tokens
      end

      def parse(tokens)
        queue = expand_short_flags(tokens)
        until queue.empty?
          token = queue.shift
          if token.start_with?("-") && token != "-"
            argument = WITH_ARGUMENT.include?(token) ? (queue.shift || raise(Invalid, I18n.t("workbench.curl.missing_argument", flag: token))) : nil
            apply_flag(token, argument)
          else
            @url ||= token
          end
        end
      end

      # `-sSL` => `-s -S -L`; `-XPOST` => `-X POST`.
      def expand_short_flags(tokens)
        tokens.flat_map do |token|
          next [token] unless token.match?(/\A-[A-Za-z]{2,}/)

          flags = []
          token[1..].each_char.with_index do |char, index|
            flags << "-#{char}"
            if SHORT_WITH_ARGUMENT.include?(char)
              rest = token[(index + 2)..]
              flags << rest if rest.present?
              break
            end
          end
          flags
        end
      end

      def apply_flag(flag, value)
        case flag
        when "-X", "--request" then @method = value.upcase
        when "-H", "--header" then @headers << value
        when "-d", "--data", "--data-raw", "--data-binary", "--data-ascii" then @data << value
        when "--data-urlencode" then @data << urlencode(value)
        when "--json"
          @json = true
          @data << value
        when "-F", "--form" then @form << value
        when "-u", "--user" then @user = value
        when "-A", "--user-agent" then @headers << "User-Agent: #{value}"
        when "-e", "--referer" then @headers << "Referer: #{value}"
        when "-b", "--cookie" then @headers << "Cookie: #{value}"
        when "-I", "--head" then @head = true
        when "-G", "--get" then @get = true
        when "-k", "--insecure" then @insecure = true
        when "-L", "--location" then @location = true
        when "-m", "--max-time" then @timeout = value.to_f.ceil
        when "--url" then @url = value
        end
      end

      def urlencode(value)
        name, separator, content = value.partition("=")
        return CGI.escape(value) if separator.empty?

        name.empty? ? CGI.escape(content) : "#{name}=#{CGI.escape(content)}"
      end

      def attributes
        url = @url
        headers = header_rows
        content_type = headers.find { |row| row["key"].casecmp?("content-type") }&.fetch("value").to_s.downcase
        payload = @data.join("&")

        if @get && payload.present?
          url = [url, payload].join(url.include?("?") ? "&" : "?")
          payload = ""
        end

        body_type, body, form_rows = classify_body(payload, content_type)
        headers.reject! { |row| row["key"].casecmp?("content-type") } if implied_content_type?(body_type, content_type)

        method = infer_method(payload)
        attributes = {
          name: name_for(method, url), http_method: ApiRequest::METHODS.include?(method) ? method : "GET", url:,
          headers:, query_params: query_rows(url), body_type:, body:, body_form: form_rows, auth_type: "inherit", auth_config: {},
          settings: { "verify_ssl" => !@insecure, "follow_redirects" => @location, "timeout" => @timeout || ApiRequest::DEFAULT_SETTINGS["timeout"] }
        }
        attributes.merge!(auth_type: "basic", auth_config: { "username" => @user.split(":", 2).first, "password" => @user.split(":", 2).last }) if @user
        attributes
      end

      DEFAULT_CONTENT_TYPES = { "json" => "application/json", "xml" => "application/xml", "form_urlencoded" => "application/x-www-form-urlencoded" }.freeze

      # The request builder adds these Content-Type values itself, so they are not kept as explicit headers.
      def implied_content_type?(body_type, content_type)
        body_type == "multipart" || DEFAULT_CONTENT_TYPES[body_type] == content_type.split(";").first.to_s.strip
      end

      def infer_method(payload)
        return @method if @method
        return "HEAD" if @head
        return "GET" if @get

        payload.present? || @form.any? ? "POST" : "GET"
      end

      def header_rows
        @headers.filter_map do |header|
          name, separator, value = header.partition(":")
          next if separator.empty?

          { "key" => name.strip, "value" => value.strip, "enabled" => true, "description" => "" }
        end
      end

      def classify_body(payload, content_type)
        return ["multipart", nil, form_rows] if @form.any?
        return ["none", nil, []] if payload.blank?
        return ["json", payload, []] if @json || content_type.include?("json") || json?(payload)
        return ["xml", payload, []] if content_type.include?("xml")
        return ["text", payload, []] if content_type.present? && !content_type.include?("x-www-form-urlencoded")

        ["form_urlencoded", nil, URI.decode_www_form(payload).map { |key, value| { "key" => key, "value" => value, "enabled" => true, "description" => "" } }]
      rescue ArgumentError
        ["text", payload, []]
      end

      def json?(payload)
        payload.lstrip.start_with?("{", "[") && JSON.parse(payload).present?
      rescue JSON::ParserError
        false
      end

      def form_rows
        @form.map do |field|
          key, _, value = field.partition("=")
          file = value.start_with?("@")
          { "key" => key, "value" => file ? value.delete_prefix("@") : value, "type" => file ? "file" : "text", "enabled" => true, "description" => "" }
        end
      end

      # Query string split by hand: URLs often hold {{variables}}, which URI would reject.
      def query_rows(url)
        query = url.to_s.split("#").first.to_s.split("?", 2)[1]
        return [] if query.blank?

        query.split("&").compact_blank.map do |pair|
          key, value = pair.split("=", 2)
          { "key" => CGI.unescape(key.to_s), "value" => CGI.unescape(value.to_s), "enabled" => true, "description" => "" }
        end
      end

      def name_for(method, url)
        "#{method} #{url.to_s.sub(%r{\A[a-z][a-z0-9+.\-]*://}i, "").split(/[?#]/).first}".truncate(80)
      end
    end
  end
end
