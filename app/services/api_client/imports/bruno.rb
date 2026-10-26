module ApiClient
  module Imports
    # Bruno collection JSON export. Result#record is the normalized tree (see Import).
    class Bruno
      include Serviceable

      OAUTH_GRANTS = { "client_credentials" => "client_credentials", "password" => "password", "authorization_code" => "authorization_code" }.freeze

      def initialize(data:)
        @data = data
        @warnings = []
      end

      private

      def perform
        inherited = auth_from(@data.dig("root", "request", "auth"))
        collection = Support.folder(name: @data["name"], **walk(@data["items"], inherited)).slice(:name, :folders, :requests)
        environments = Array(@data["environments"]).filter_map { |environment| environment_from(environment) if environment.is_a?(Hash) }
        Result.success({ collections: [collection], environments:, warnings: @warnings })
      end

      def environment_from(environment)
        variables = Array(environment["variables"]).filter_map do |entry|
          Support.variable(entry["name"], entry["value"], secret: entry["secret"], enabled: entry["enabled"]) if entry["name"].present?
        end
        Support.environment(name: environment["name"], variables:)
      end

      def walk(items, inherited)
        folders = []
        requests = []
        Array(items).sort_by { |item| item.is_a?(Hash) ? item["seq"].to_i : 0 }.each do |item|
          next unless item.is_a?(Hash)

          case item["type"]
          when "folder"
            own = auth_from(item.dig("root", "request", "auth"))
            folders << Support.folder(name: item["name"], **(own || inherited || {}).slice(:auth_type, :auth_config), **walk(item["items"], nil))
          when "http-request", "graphql-request"
            requests << request_from(item, inherited)
          else
            add_warning(:unknown_item, type: item["type"])
          end
        end
        { folders:, requests: }
      end

      def request_from(item, inherited)
        raw = item["request"].is_a?(Hash) ? item["request"] : {}
        warn_scripts(item, raw)
        attributes = Support.request(
          name: item["name"], http_method: raw["method"] || "GET", url: raw["url"], headers: rows(raw["headers"]),
          query_params: rows(Array(raw["params"]).select { |param| param["type"] == "query" }), **body_attributes(raw["body"], item["name"])
        )
        attributes.merge!(auth_from(raw["auth"]) || inherited || {})
        VariableConverter.request(attributes, @warnings)
      end

      def rows(entries)
        Array(entries).filter_map do |entry|
          Support.row(entry["name"], entry["value"], enabled: entry["enabled"] != false) if entry["name"].present?
        end
      end

      def body_attributes(body, name)
        return {} unless body.is_a?(Hash)

        case body["mode"]
        when "json", "xml", "text" then { body_type: body["mode"], body: body[body["mode"]].to_s }
        when "formUrlEncoded" then { body_type: "form_urlencoded", body_form: rows(body["formUrlEncoded"]) }
        when "multipartForm" then { body_type: "multipart", body_form: form_rows(body["multipartForm"], name) }
        when "graphql" then { body_type: "graphql", body: body.dig("graphql", "query"), graphql_variables: body.dig("graphql", "variables") }
        when "file" then file_body(name)
        else {}
        end
      end

      def form_rows(entries, name)
        Array(entries).filter_map do |entry|
          next if entry["name"].blank?

          file = entry["type"] == "file"
          add_warning(:file_body, name:) if file
          value = file ? File.basename(Array(entry["value"]).first.to_s) : entry["value"]
          Support.row(entry["name"], value, enabled: entry["enabled"] != false).merge("type" => file ? "file" : "text")
        end
      end

      def file_body(name)
        add_warning(:file_body, name:)
        {}
      end

      def auth_from(auth)
        mode = auth.is_a?(Hash) ? auth["mode"] : nil
        return if mode.blank? || mode == "inherit"

        fields = auth[mode].is_a?(Hash) ? auth[mode] : {}
        case mode
        when "none" then AuthMapper.call("none", {}, @warnings)
        when "basic", "digest" then AuthMapper.call(mode, fields.slice("username", "password"), @warnings)
        when "bearer" then AuthMapper.call("bearer", { "token" => fields["token"], "prefix" => "Bearer" }, @warnings)
        when "apikey" then AuthMapper.call("api_key", { "key" => fields["key"], "value" => fields["value"], "add_to" => fields["placement"] == "queryparams" ? "query" : "header" }, @warnings)
        when "awsv4" then AuthMapper.call("aws_sigv4", { "access_key" => fields["accessKeyId"], "secret_key" => fields["secretAccessKey"], "session_token" => fields["sessionToken"], "region" => fields["region"], "service" => fields["service"] }, @warnings)
        when "oauth2" then oauth2(fields)
        else AuthMapper.call(mode, {}, @warnings)
        end
      end

      def oauth2(fields)
        grant = OAUTH_GRANTS[fields["grantType"]]
        return AuthMapper.call(fields["grantType"] || "oauth2", {}, @warnings) unless grant

        AuthMapper.call("oauth2", {
          "grant_type" => grant, "token_url" => fields["accessTokenUrl"], "authorization_url" => fields["authorizationUrl"], "client_id" => fields["clientId"],
          "client_secret" => fields["clientSecret"], "username" => fields["username"], "password" => fields["password"], "scope" => fields["scope"]
        }, @warnings)
      end

      def warn_scripts(item, request)
        scripts = [request.dig("script", "req"), request.dig("script", "res"), request["tests"]]
        add_warning(:scripts, name: item["name"]) if scripts.any?(&:present?)
      end

      def add_warning(key, **options)
        @warnings << I18n.t("workbench.imports.warnings.#{key}", **options)
      end
    end
  end
end
