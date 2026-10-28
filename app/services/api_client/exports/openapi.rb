module ApiClient
  module Exports
    # OpenAPI 3.0 draft of the collection: one operation per request (the first one wins when two share method and path),
    # folders as tags, the server taken from the base URL variable. It documents the contract, so credentials and
    # environments are not part of it (only the variable that holds the base URL is read to fill `servers`).
    class Openapi
      include Serviceable

      ORIGIN = %r{\A(\{\{\s*[^{}]+?\s*\}\}|[a-z][a-z0-9+.-]*://[^/?#]+)?([^?#]*)}i
      IGNORED_HEADERS = %w[content-type accept authorization].freeze
      PLACEHOLDER = /\{\{\s*([^{}$]+?)\s*\}\}/

      def initialize(collection:, environments:, credentials:, progress: nil)
        @collection = collection
        @environments = environments
        @credentials = credentials
        @tree = Tree.new(collection, progress:)
        @paths = {}
        @servers = []
        @schemes = {}
      end

      private

      def perform
        walk(nil, [], @collection)
        document = { openapi: "3.0.3", info: { title: @collection.name, description: @collection.description.presence, version: "1.0.0" }.compact }
        document[:servers] = @servers.uniq.map { |url| { url: } } if @servers.any?
        document[:paths] = @paths
        document[:components] = { securitySchemes: @schemes } if @schemes.any?
        Result.success(nil, document:)
      end

      def walk(folder, tags, inherited)
        @tree.requests_in(folder).each { |api_request| operation(api_request, tags, api_request.inherits_auth? ? inherited : api_request) }
        @tree.folders_in(folder).each { |child| walk(child, tags + [child.name], child.inherits_auth? ? inherited : child) }
      end

      def operation(api_request, tags, auth)
        origin, path = split(api_request.url)
        @servers << origin if origin
        method = api_request.http_method.downcase
        item = (@paths[path] ||= {})
        return if item.key?(method)

        parameters = path_parameters(path) + query_parameters(api_request) + header_parameters(api_request)
        item[method] = {
          summary: api_request.name, description: api_request.description.presence, tags: tags.empty? ? nil : [tags.join(" / ")], parameters: parameters.presence,
          requestBody: request_body(api_request), security: security(auth)
        }.compact
        item[method][:responses] = { "200" => { description: "Successful response" } }
      end

      def split(url)
        match = ORIGIN.match(url.to_s)
        origin = resolve(match[1])
        path = match[2].to_s.gsub(PLACEHOLDER) { "{#{Regexp.last_match(1)}}" }
        [origin, path.start_with?("/") ? path : "/#{path}"]
      end

      def resolve(origin)
        return origin unless origin&.start_with?("{{")

        name = origin[/\{\{\s*([^{}]+?)\s*\}\}/, 1]
        @environments.each do |environment|
          variable = environment.variables.find { |candidate| candidate.key == name && candidate.enabled }
          value = variable && @credentials.variable_value(variable)
          return value.chomp("/") if value.present?
        end
        nil
      end

      def path_parameters(path)
        path.scan(/\{([^{}]+)\}/).flatten.uniq.map { |name| { name:, in: "path", required: true, schema: { type: "string" } } }
      end

      def query_parameters(api_request)
        api_request.query_params.map { |row| { name: row["key"], in: "query", required: false, description: row["description"].presence, schema: { type: "string" }, example: row["value"].presence }.compact }
      end

      def header_parameters(api_request)
        api_request.headers.reject { |row| IGNORED_HEADERS.include?(row["key"].downcase) }.map do |row|
          { name: row["key"], in: "header", required: false, description: row["description"].presence, schema: { type: "string" }, example: row["value"].presence }.compact
        end
      end

      def request_body(api_request)
        content =
          case api_request.body_type
          when "json" then { "application/json" => { schema: { type: "object" }, example: json_example(api_request.body) }.compact }
          when "xml" then { "application/xml" => { schema: { type: "string" }, example: api_request.body.to_s } }
          when "text" then { "text/plain" => { schema: { type: "string" }, example: api_request.body.to_s } }
          when "form_urlencoded" then { "application/x-www-form-urlencoded" => { schema: form_schema(api_request.body_form) } }
          when "multipart" then { "multipart/form-data" => { schema: form_schema(api_request.body_form) } }
          when "graphql" then { "application/json" => { schema: { type: "object" }, example: { query: api_request.body.to_s, variables: json_example(api_request.graphql_variables) }.compact } }
          end
        { content: } if content
      end

      def form_schema(rows)
        properties = rows.to_h { |row| [row["key"], row["type"] == "file" ? { type: "string", format: "binary" } : { type: "string", example: row["value"].presence }.compact] }
        { type: "object", properties: }
      end

      def json_example(text)
        JSON.parse(text.to_s)
      rescue JSON::ParserError
        text.to_s.presence
      end

      def security(auth)
        name = scheme_for(auth)
        [{ name => [] }] if name
      end

      def scheme_for(auth)
        case auth.auth_type
        when "basic", "digest" then register("#{auth.auth_type}Auth", { type: "http", scheme: auth.auth_type })
        when "bearer", "jwt_bearer", "oauth2" then register("bearerAuth", { type: "http", scheme: "bearer" })
        when "api_key"
          config = auth.auth_config.to_h
          location = config["add_to"] == "query" ? "query" : "header"
          register("apiKey_#{config["key"].to_s.gsub(/\W/, "_")}", { type: "apiKey", name: config["key"].to_s, in: location })
        end
      end

      def register(name, scheme)
        @schemes[name] ||= scheme
        name
      end
    end
  end
end
