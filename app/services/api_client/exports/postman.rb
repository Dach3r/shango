module ApiClient
  module Exports
    # Postman collection v2.1 plus, on demand, one Postman environment file per environment (the pair is zipped by Export).
    class Postman
      include Serviceable

      SCHEMA = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json".freeze
      GRANTS = { "client_credentials" => "client_credentials", "password" => "password_credentials", "authorization_code" => "authorization_code" }.freeze

      def initialize(collection:, environments:, credentials:, progress: nil)
        @collection = collection
        @environments = environments
        @credentials = credentials
        @tree = Tree.new(collection, progress:)
      end

      private

      def perform
        Result.success(nil, collection: collection_document, environments: @environments.map { |environment| environment_document(environment) })
      end

      def collection_document
        { info: { name: @collection.name, description: @collection.description.to_s, schema: SCHEMA }, auth: auth_for(@collection), event: events(@collection), item: items(nil) }.compact
      end

      def environment_document(environment)
        values = environment.variables.map do |variable|
          { key: variable.key, value: @credentials.variable_value(variable), type: variable.secret ? "secret" : "default", enabled: variable.enabled }
        end
        { id: environment.id, name: environment.name, values:, _postman_variable_scope: "environment" }
      end

      def items(folder)
        folders = @tree.folders_in(folder).map { |child| { name: child.name, auth: auth_for(child), event: events(child), item: items(child) }.compact }
        folders + @tree.requests_in(folder).map { |api_request| request_item(api_request) }
      end

      def request_item(api_request)
        { name: api_request.name, event: events(api_request), request: { method: api_request.http_method, header: rows(api_request.headers), url: url_for(api_request), body: body_for(api_request), auth: auth_for(api_request), description: api_request.description.presence }.compact }.compact
      end

      # The pre-request script, and one `test` script made of the generated assertions and extractors plus the post-response script.
      def events(record)
        tests = [AssertionScript.call(assertions: record.assertions, extractors: record.extractors).record, record.post_response_script].compact_blank.join("\n").presence
        events = { "prerequest" => record.pre_request_script.presence, "test" => tests }.compact.map do |listen, source|
          { listen:, script: { type: "text/javascript", exec: source.lines.map(&:chomp) } }
        end
        events.presence
      end

      def url_for(api_request)
        { raw: api_request.url, query: rows(api_request.query_params) }
      end

      def rows(rows)
        rows.map { |row| { key: row["key"], value: row["value"], disabled: !row["enabled"], description: row["description"].presence }.compact }
      end

      def body_for(api_request)
        case api_request.body_type
        when "json", "xml", "text" then { mode: "raw", raw: api_request.body.to_s, options: { raw: { language: api_request.body_type } } }
        when "form_urlencoded" then { mode: "urlencoded", urlencoded: rows(api_request.body_form) }
        when "multipart" then { mode: "formdata", formdata: api_request.body_form.map { |row| form_row(row) } }
        when "graphql" then { mode: "graphql", graphql: { query: api_request.body.to_s, variables: api_request.graphql_variables.to_s } }
        end
      end

      def form_row(row)
        file = row["type"] == "file"
        { key: row["key"], disabled: !row["enabled"], type: file ? "file" : "text" }.merge(file ? { src: row["value"] } : { value: row["value"] })
      end

      def auth_for(record)
        return if record.auth_type == AuthConfigurable::INHERIT

        config = @credentials.auth_config(record)
        case record.auth_type
        when "none" then (record.is_a?(Collection) ? nil : { type: "noauth" })
        when "basic", "digest" then typed(record.auth_type, config.slice("username", "password"))
        when "bearer" then typed("bearer", { "token" => config["token"] })
        when "api_key" then typed("apikey", { "key" => config["key"], "value" => config["value"], "in" => config["add_to"] == "query" ? "query" : "header" })
        when "aws_sigv4" then typed("awsv4", { "accessKey" => config["access_key"], "secretKey" => config["secret_key"], "sessionToken" => config["session_token"], "region" => config["region"], "service" => config["service"] })
        when "oauth2" then typed("oauth2", oauth2_fields(config))
        end
      end

      def oauth2_fields(config)
        {
          "grant_type" => GRANTS[config["grant_type"]], "accessTokenUrl" => config["token_url"], "authUrl" => config["authorization_url"], "clientId" => config["client_id"],
          "clientSecret" => config["client_secret"], "username" => config["username"], "password" => config["password"], "scope" => config["scope"]
        }.compact
      end

      def typed(type, fields)
        { type:, type => fields.map { |key, value| { key:, value: value.to_s, type: "string" } } }
      end
    end
  end
end
