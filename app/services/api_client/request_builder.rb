module ApiClient
  # Turns a saved (or edited, unsaved) ApiRequest plus an environment into everything the executor needs:
  # resolved URL, headers, body and authentication. Returns Result#record = Built.
  class RequestBuilder
    include Serviceable

    Built = Struct.new(
      :http_method, :url, :headers, :body, :timeout, :follow_redirects, :max_redirects, :verify_ssl,
      :auth, :unresolved, :secrets, :defaults_added, keyword_init: true
    )

    # `factory` builds a fresh payload per attempt (redirects, digest retry); `preview` is what history stores;
    # `raw` and `form` feed the cURL exporter.
    Body = Struct.new(:factory, :preview, :multipart, :raw, :form, keyword_init: true)

    DEFAULT_HEADERS = { "User-Agent" => "Shango/1.0", "Accept" => "*/*" }.freeze
    CONTENT_TYPES = { "json" => "application/json", "text" => "text/plain", "xml" => "application/xml", "form_urlencoded" => "application/x-www-form-urlencoded" }.freeze
    BODYLESS_METHODS = %w[GET HEAD].freeze

    class InvalidRequest < StandardError; end

    def initialize(api_request:, environment: nil, dry_run: false)
      @api_request = api_request
      @environment = environment
      @dry_run = dry_run
      @resolver = VariableResolver.new(environment&.variable_values || {})
    end

    private

    def perform
      url = resolved_url
      headers = resolved_headers
      defaults_added = add_default_headers(headers)
      body = build_body(headers)
      auth_request = Auth::Request.new(http_method: @api_request.http_method, url:, headers:, body: body_string(body))
      strategy = apply_auth(auth_request)

      Result.success(Built.new(
        http_method: @api_request.http_method, url: auth_request.url, headers: auth_request.headers, body:,
        timeout: @api_request.setting(:timeout), follow_redirects: @api_request.setting(:follow_redirects),
        max_redirects: @api_request.setting(:max_redirects), verify_ssl: @api_request.setting(:verify_ssl), auth: strategy,
        unresolved: @resolver.unresolved.to_a.sort, secrets: secrets(strategy), defaults_added:
      ))
    rescue InvalidRequest, Auth::ConfigurationError => error
      Result.failure(error: error.message, unresolved: @resolver.unresolved.to_a.sort)
    end

    def resolved_url
      raw = @resolver.resolve(@api_request.url.to_s.strip)
      raise InvalidRequest, I18n.t("api_client.errors.blank_url") if raw.blank?
      raise InvalidRequest, I18n.t("api_client.errors.unresolved_url", names: @resolver.unresolved.to_a.sort.join(", ")) if @resolver.unresolved.any?

      url = raw.match?(%r{\A[a-z][a-z0-9+.\-]*://}i) ? raw : "http://#{raw}"
      uri = URI.parse(url)
      raise InvalidRequest, I18n.t("api_client.errors.invalid_url") unless uri.is_a?(URI::HTTP) && uri.host.present?

      url
    rescue URI::InvalidURIError
      raise InvalidRequest, I18n.t("api_client.errors.invalid_url")
    end

    def resolved_headers
      @api_request.headers.select { |row| row["enabled"] && row["key"].present? }.each_with_object({}) do |row, headers|
        name = @resolver.resolve(row["key"]).strip
        value = @resolver.resolve(row["value"])
        headers[name] = headers.key?(name) ? "#{headers[name]}, #{value}" : value
      end
    end

    def add_default_headers(headers)
      DEFAULT_HEADERS.filter_map do |name, value|
        next if headers.keys.any? { |key| key.casecmp?(name) }

        headers[name] = value
        name
      end
    end

    def build_body(headers)
      type = @api_request.body_type
      return empty_body if type == "none" || BODYLESS_METHODS.include?(@api_request.http_method)

      case type
      when "json", "text", "xml" then raw_body(type, headers, @resolver.resolve(@api_request.body.to_s))
      when "graphql" then raw_body("json", headers, graphql_payload)
      when "form_urlencoded" then raw_body("form_urlencoded", headers, URI.encode_www_form(resolved_rows(@api_request.body_form)))
      when "multipart" then multipart_body(headers)
      when "binary" then binary_body(headers)
      else empty_body
      end
    end

    def empty_body
      Body.new(factory: -> { }, preview: nil, multipart: false)
    end

    def raw_body(type, headers, string)
      set_content_type(headers, CONTENT_TYPES.fetch(type))
      Body.new(factory: -> { string }, preview: string, multipart: false, raw: string)
    end

    def graphql_payload
      raw_variables = @resolver.resolve(@api_request.graphql_variables.to_s).strip
      variables = raw_variables.empty? ? {} : JSON.parse(raw_variables)
      JSON.generate(query: @resolver.resolve(@api_request.body.to_s), variables:)
    rescue JSON::ParserError
      raise InvalidRequest, I18n.t("api_client.errors.invalid_graphql_variables")
    end

    def multipart_body(headers)
      rows = @api_request.body_form.select { |row| row["enabled"] && row["key"].present? }
      set_content_type(headers, "multipart/form-data")
      files = @api_request.body_files.index_by { |attachment| attachment.id.to_s }
      file_row = ->(row) { row["type"] == "file" && files[row["attachment_id"].to_s] }

      form = rows.map { |row| [@resolver.resolve(row["key"]), file_row.call(row) ? "@#{file_row.call(row).filename}" : @resolver.resolve(row["value"])] }
      factory = lambda do
        rows.to_h do |row|
          key = @resolver.resolve(row["key"])
          attachment = file_row.call(row)
          next [key, @resolver.resolve(row["value"])] unless attachment

          [key, Faraday::Multipart::FilePart.new(StringIO.new(attachment.download), attachment.content_type.presence || "application/octet-stream", attachment.filename.to_s)]
        end
      end

      Body.new(factory:, preview: form.map { |key, value| "#{key}=#{value}" }.join("\n"), multipart: true, form:)
    end

    def binary_body(headers)
      attachment = @api_request.binary_body
      raise InvalidRequest, I18n.t("api_client.errors.missing_binary") unless attachment.attached?

      set_content_type(headers, attachment.content_type.presence || "application/octet-stream")
      Body.new(factory: -> { attachment.download }, preview: "[binary #{attachment.filename} · #{attachment.byte_size} bytes]", multipart: false)
    end

    def resolved_rows(rows)
      rows.select { |row| row["enabled"] && row["key"].present? && row["type"] != "file" }.map { |row| [@resolver.resolve(row["key"]), @resolver.resolve(row["value"])] }
    end

    def set_content_type(headers, value)
      headers["Content-Type"] = value unless headers.keys.any? { |key| key.casecmp?("content-type") }
    end

    # Signing strategies need the final body as a string; streams are signed as an empty payload.
    def body_string(body)
      body.raw if body.raw.is_a?(String)
    end

    def apply_auth(auth_request)
      auth = Auth::EffectiveAuth.call(api_request: @api_request)
      strategy = Auth::Registry.fetch(auth.type).new(@resolver.resolve_deep(auth.config), owner: auth.owner, dry_run: @dry_run)
      strategy.apply(auth_request)
      strategy
    end

    def secrets(strategy)
      (@environment&.secret_values || []) + strategy.secrets
    end
  end
end
