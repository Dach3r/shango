module ApiClient
  module Imports
    # OpenAPI 3.x and Swagger 2.0 documents: tags become folders, each operation a request and the server a `baseUrl` variable.
    class Openapi
      include Serviceable

      HTTP_METHODS = %w[get put post delete patch head options].freeze
      IGNORED_HEADERS = %w[accept content-type authorization].freeze
      MAX_SCHEMA_DEPTH = 5
      MAX_REF_DEPTH = 10
      OAUTH_FLOWS = {
        "clientCredentials" => "client_credentials", "password" => "password", "authorizationCode" => "authorization_code",
        "application" => "client_credentials", "accessCode" => "authorization_code"
      }.freeze

      def initialize(data:)
        @data = data
        @warnings = []
      end

      private

      def perform
        paths = @data["paths"]
        return Result.failure(error: I18n.t("workbench.imports.errors.invalid_openapi")) unless paths.is_a?(Hash) && paths.any?

        base = base_url
        folders = {}
        requests = []
        operations(paths) do |path, method, operation, shared|
          request = request_from(path, method, operation, shared, base)
          tag = Array(operation["tags"]).first
          tag ? (folders[tag] ||= []) << request : requests << request
        end
        title = @data.dig("info", "title")
        collection = Support.folder(name: title, folders: folders.map { |name, items| Support.folder(name:, requests: items) }, requests:).slice(:name, :folders, :requests)
        collection[:description] = @data.dig("info", "description").presence
        environments = base ? [Support.environment(name: title, variables: [Support.variable("baseUrl", base)])] : []
        Result.success({ collections: [collection], environments:, warnings: @warnings })
      end

      def operations(paths)
        paths.each do |path, item|
          next unless item.is_a?(Hash)

          HTTP_METHODS.each do |method|
            yield path, method, item[method], Array(item["parameters"]) if item[method].is_a?(Hash)
          end
        end
      end

      def base_url
        if @data["openapi"]
          server = Array(@data["servers"]).first
          return unless server.is_a?(Hash) && server["url"].present?

          server["url"].gsub(/\{([^}]+)\}/) { server.dig("variables", Regexp.last_match(1), "default").to_s }
        elsif @data["host"].present?
          "#{Array(@data["schemes"]).first || "https"}://#{@data["host"]}#{@data["basePath"]}".chomp("/")
        end
      end

      def request_from(path, method, operation, shared, base)
        params = parameters(shared + Array(operation["parameters"]))
        attributes = Support.request(
          name: operation["summary"].presence || operation["operationId"].presence || "#{method.upcase} #{path}",
          http_method: method, url: "#{base ? "{{baseUrl}}" : ""}#{path.gsub(/\{([^}]+)\}/, '{{\1}}')}", description: operation["description"].presence,
          query_params: params[:query], headers: params[:header], **body_attributes(operation, params)
        )
        attributes.merge!(auth_attributes(operation))
        VariableConverter.request(attributes, @warnings)
      end

      def parameters(list)
        resolved = list.map { |param| deref(param) }.select { |param| param["name"].present? }.uniq { |param| [param["in"], param["name"]] }
        {
          query: resolved.select { |param| param["in"] == "query" }.map { |param| Support.row(param["name"], scalar(param), enabled: param["required"] == true, description: param["description"]) },
          header: resolved.select { |param| param["in"] == "header" && !IGNORED_HEADERS.include?(param["name"].downcase) }.map { |param| Support.row(param["name"], scalar(param), enabled: param["required"] == true) },
          body: resolved.find { |param| param["in"] == "body" }, form: resolved.select { |param| param["in"] == "formData" }
        }
      end

      def scalar(param)
        value = param.key?("example") ? param["example"] : example(param["schema"] || param)
        value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value.to_s
      end

      def body_attributes(operation, params)
        if operation["requestBody"]
          content = deref(operation["requestBody"])["content"]
          return {} unless content.is_a?(Hash) && content.any?

          mime = content.keys.find { |key| key.include?("json") } || content.keys.first
          media = deref(content[mime])
          body_for(Support.body_type_for(mime), media["schema"], media)
        elsif params[:body]
          body_for(Support.body_type_for(Array(operation["consumes"] || @data["consumes"]).first || "application/json"), params[:body]["schema"], params[:body])
        elsif params[:form].any?
          type = Array(operation["consumes"] || @data["consumes"]).first.to_s.include?("multipart") ? "multipart" : "form_urlencoded"
          { body_type: type, body_form: params[:form].map { |param| form_row(param["name"], param) } }
        else
          {}
        end
      end

      def body_for(type, schema, media)
        case type
        when "form_urlencoded", "multipart"
          properties = deref(schema)["properties"].to_h
          { body_type: type, body_form: properties.map { |name, property| form_row(name, deref(property)) } }
        else
          sample = media.key?("example") ? media["example"] : first_example(media["examples"]) || example(schema)
          { body_type: type, body: body_text(sample, type) }
        end
      end

      def body_text(sample, type)
        return "" if sample.nil?
        return JSON.pretty_generate(sample) unless sample.is_a?(String)
        return sample unless type == "json"

        JSON.parse(sample)
        sample
      rescue JSON::ParserError
        sample.to_json
      end

      def first_example(examples)
        examples.is_a?(Hash) ? deref(examples.values.first)["value"] : nil
      end

      def form_row(name, schema)
        file = schema["format"] == "binary" || schema["type"] == "file"
        Support.row(name, file ? "" : scalar(schema)).merge("type" => file ? "file" : "text")
      end

      def auth_attributes(operation)
        requirement = (operation.key?("security") ? operation["security"] : @data["security"]).then { |list| Array(list).first }
        return {} unless requirement.is_a?(Hash) && requirement.any?

        scheme = deref(schemes[requirement.keys.first])
        scheme_auth(scheme).slice(:auth_type, :auth_config)
      end

      def schemes
        @data.dig("components", "securitySchemes") || @data["securityDefinitions"] || {}
      end

      def scheme_auth(scheme)
        case scheme["type"]
        when "basic" then AuthMapper.call("basic", {}, @warnings)
        when "http" then http_auth(scheme)
        when "apiKey" then scheme["in"] == "cookie" ? AuthMapper.call("cookie", {}, @warnings) : AuthMapper.call("api_key", { "key" => scheme["name"], "add_to" => scheme["in"] == "query" ? "query" : "header" }, @warnings)
        when "oauth2" then oauth2(scheme)
        else AuthMapper.call(scheme["type"].presence || "unknown", {}, @warnings)
        end
      end

      def http_auth(scheme)
        case scheme["scheme"].to_s.downcase
        when "basic" then AuthMapper.call("basic", {}, @warnings)
        when "bearer" then AuthMapper.call("bearer", { "prefix" => "Bearer" }, @warnings)
        else AuthMapper.call("http_#{scheme["scheme"]}", {}, @warnings)
        end
      end

      def oauth2(scheme)
        flows = scheme["flows"].is_a?(Hash) ? scheme["flows"] : { scheme["flow"] => scheme }
        name, flow = flows.find { |key, _| OAUTH_FLOWS.key?(key) }
        return AuthMapper.call("oauth2_#{flows.keys.first}", {}, @warnings) unless name

        AuthMapper.call("oauth2", {
          "grant_type" => OAUTH_FLOWS[name], "token_url" => flow["tokenUrl"], "authorization_url" => flow["authorizationUrl"], "scope" => flow["scopes"].to_h.keys.join(" ")
        }, @warnings)
      end

      def deref(node, depth = 0)
        return {} unless node.is_a?(Hash)
        return node unless node["$ref"].is_a?(String)

        ref = node["$ref"]
        unless ref.start_with?("#/") && depth < MAX_REF_DEPTH
          @warnings << I18n.t("workbench.imports.warnings.external_ref", ref:)
          return {}
        end

        deref(@data.dig(*ref.delete_prefix("#/").split("/").map { |part| part.gsub("~1", "/").gsub("~0", "~") }), depth + 1)
      end

      def example(schema, depth = 0)
        schema = deref(schema)
        return if depth > MAX_SCHEMA_DEPTH || schema.empty?
        return schema["example"] if schema.key?("example")
        return schema["default"] if schema.key?("default")
        return schema["enum"].first if schema["enum"].is_a?(Array) && schema["enum"].any?
        return example(Array(schema["oneOf"] || schema["anyOf"]).first, depth + 1) if schema["oneOf"] || schema["anyOf"]

        schema = Array(schema["allOf"]).reduce(schema.except("allOf")) { |merged, part| merged.deep_merge(deref(part)) } if schema["allOf"]
        case schema["type"] || ("object" if schema["properties"])
        when "object" then schema["properties"].to_h.transform_values { |property| example(property, depth + 1) }
        when "array" then [example(schema["items"], depth + 1)]
        when "integer", "number" then 0
        when "boolean" then false
        else "string"
        end
      end
    end
  end
end
