module ApiClient
  module Imports
    # Postman collection v2.x and environment exports. Result#record is the normalized tree (see Import).
    class Postman
      include Serviceable

      def initialize(data:)
        @data = data
        @warnings = []
      end

      private

      def perform
        tree = @data.key?("info") ? collection_tree : environment_tree
        Result.success(tree.merge(warnings: @warnings))
      end

      def collection_tree
        name = @data.dig("info", "name")
        auth = auth_from(@data["auth"])
        collection = Support.folder(name:, **walk(@data["item"], auth)).slice(:name, :folders, :requests)
        collection[:description] = text(@data.dig("info", "description"))
        collection.merge!(scripts_from(@data, name))
        variables = Array(@data["variable"]).filter_map { |entry| Support.variable(entry["key"], entry["value"]) if entry["key"].present? }
        environments = variables.any? ? [Support.environment(name: "#{collection[:name]} variables", variables:)] : []
        { collections: [collection], environments: }
      end

      def environment_tree
        variables = Array(@data["values"]).filter_map do |entry|
          Support.variable(entry["key"], entry["value"], secret: entry["type"] == "secret", enabled: entry["enabled"]) if entry["key"].present?
        end
        { collections: [], environments: [Support.environment(name: @data["name"], variables:)] }
      end

      def walk(items, inherited)
        folders = []
        requests = []
        Array(items).each do |item|
          next unless item.is_a?(Hash)

          if item.key?("item")
            own = auth_from(item["auth"])
            folder = Support.folder(name: item["name"], **own_auth(own || inherited), **walk(item["item"], nil).slice(:folders, :requests))
            folders << folder.merge(scripts_from(item, item["name"]))
          else
            requests << request_from(item, inherited)
          end
        end
        { folders:, requests: }
      end

      def own_auth(auth)
        auth ? { auth_type: auth[:auth_type], auth_config: auth[:auth_config] } : {}
      end

      def request_from(item, inherited)
        raw = item["request"].is_a?(Hash) ? item["request"] : { "url" => item["request"].to_s }
        query = url_query(raw["url"])
        attributes = Support.request(
          name: item["name"], http_method: raw["method"] || "GET", url: url_raw(raw["url"]), query_params: query,
          headers: rows(raw["header"]), description: text(raw["description"]), **body_attributes(raw["body"], item["name"])
        )
        auth = auth_from(raw["auth"]) || inherited
        attributes.merge!(auth) if auth
        VariableConverter.request(attributes, @warnings).merge(scripts_from(item, item["name"]))
      end

      def url_raw(url)
        return url.to_s unless url.is_a?(Hash)
        return url["raw"].to_s.split("?", 2).first.to_s if url["raw"].present?

        host = Array(url["host"]).join(".")
        "#{url["protocol"] ? "#{url["protocol"]}://" : ""}#{host}#{"/#{Array(url["path"]).join("/")}" if url["path"].present?}"
      end

      def url_query(url)
        return query_from_string(url.to_s) unless url.is_a?(Hash)

        entries = url["query"]
        return query_from_string(url["raw"].to_s) unless entries.is_a?(Array)

        entries.filter_map { |entry| Support.row(entry["key"], entry["value"], enabled: !entry["disabled"], description: text(entry["description"])) if entry["key"].present? }
      end

      def query_from_string(url)
        query = url.split("#").first.to_s.split("?", 2)[1]
        return [] if query.blank?

        query.split("&").compact_blank.map do |pair|
          key, value = pair.split("=", 2)
          Support.row(CGI.unescape(key.to_s), CGI.unescape(value.to_s))
        end
      end

      def rows(entries)
        Array(entries).filter_map do |entry|
          Support.row(entry["key"], entry["value"], enabled: !entry["disabled"], description: text(entry["description"])) if entry["key"].present?
        end
      end

      def body_attributes(body, name)
        return {} unless body.is_a?(Hash)

        case body["mode"]
        when "raw" then raw_body(body)
        when "urlencoded" then { body_type: "form_urlencoded", body_form: rows(body["urlencoded"]) }
        when "formdata" then { body_type: "multipart", body_form: form_rows(body["formdata"], name) }
        when "graphql" then { body_type: "graphql", body: body.dig("graphql", "query"), graphql_variables: body.dig("graphql", "variables") }
        when "file", "binary" then file_body(name)
        else {}
        end
      end

      def raw_body(body)
        language = body.dig("options", "raw", "language")
        { body_type: language == "json" || language == "xml" ? language : "text", body: body["raw"].to_s }
      end

      def form_rows(entries, name)
        Array(entries).filter_map do |entry|
          next if entry["key"].blank?

          if entry["type"] == "file"
            add_warning(:file_body, name:)
            Support.row(entry["key"], Array(entry["src"]).first.to_s.split("/").last, enabled: !entry["disabled"]).merge("type" => "file")
          else
            Support.row(entry["key"], entry["value"], enabled: !entry["disabled"]).merge("type" => "text")
          end
        end
      end

      def file_body(name)
        add_warning(:file_body, name:)
        {}
      end

      def auth_from(auth)
        return unless auth.is_a?(Hash) && auth["type"].present?

        type = auth["type"]
        fields = Array(auth[type]).to_h { |entry| [entry["key"], entry["value"]] }
        case type
        when "noauth" then AuthMapper.call("none", {}, @warnings)
        when "basic", "digest" then AuthMapper.call(type, fields.slice("username", "password"), @warnings)
        when "bearer" then AuthMapper.call("bearer", { "token" => fields["token"], "prefix" => "Bearer" }, @warnings)
        when "apikey" then AuthMapper.call("api_key", { "key" => fields["key"], "value" => fields["value"], "add_to" => fields["in"] == "query" ? "query" : "header" }, @warnings)
        when "awsv4" then AuthMapper.call("aws_sigv4", { "access_key" => fields["accessKey"], "secret_key" => fields["secretKey"], "session_token" => fields["sessionToken"], "region" => fields["region"], "service" => fields["service"] }, @warnings)
        when "oauth2" then oauth2(fields)
        else AuthMapper.call(type, {}, @warnings)
        end
      end

      OAUTH_GRANTS = { "client_credentials" => "client_credentials", "password_credentials" => "password", "authorization_code" => "authorization_code", "authorization_code_with_pkce" => "authorization_code" }.freeze

      def oauth2(fields)
        grant = OAUTH_GRANTS[fields["grant_type"]]
        return AuthMapper.call("bearer", { "token" => fields["accessToken"], "prefix" => "Bearer" }, @warnings) unless grant && fields["accessTokenUrl"].present?

        AuthMapper.call("oauth2", {
          "grant_type" => grant, "token_url" => fields["accessTokenUrl"], "authorization_url" => fields["authUrl"], "client_id" => fields["clientId"],
          "client_secret" => fields["clientSecret"], "username" => fields["username"], "password" => fields["password"], "scope" => fields["scope"]
        }, @warnings)
      end

      # `prerequest` events become the pre-request script and `test` events the post-response script. Calls Shango's `pm` lacks are reported.
      def scripts_from(item, name)
        events = Array(item["event"]).select { |event| event.is_a?(Hash) }
        scripts = { pre_request_script: script_for(events, "prerequest"), post_response_script: script_for(events, "test") }.compact
        apis = Support.unsupported_apis(scripts.values.join("\n"))
        add_warning(:scripts_unsupported, name: name.to_s, apis: apis.join(", ")) if apis.any?
        scripts
      end

      def script_for(events, listen)
        events.select { |event| event["listen"] == listen }.map { |event| Array(event.dig("script", "exec")).join("\n") }.join("\n").strip.presence
      end

      def add_warning(key, **options)
        @warnings << I18n.t("workbench.imports.warnings.#{key}", **options)
      end

      def text(description)
        (description.is_a?(Hash) ? description["content"] : description).to_s.presence
      end
    end
  end
end
