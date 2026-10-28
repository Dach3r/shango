module ApiClient
  module Exports
    # Insomnia v4 export: a workspace with its request groups and requests, and each environment as a sub-environment of the base one.
    class Insomnia
      include Serviceable

      GRANTS = %w[client_credentials password authorization_code].freeze

      def initialize(collection:, environments:, credentials:, progress: nil)
        @collection = collection
        @environments = environments
        @credentials = credentials
        @tree = Tree.new(collection, progress:)
        @resources = []
        @order = 0
      end

      private

      def perform
        workspace = { _id: id(@collection), _type: "workspace", parentId: nil, name: @collection.name, description: @collection.description.to_s, scope: "collection" }
        @resources << workspace
        add_children(nil, workspace[:_id])
        add_environments(workspace[:_id])
        Result.success(nil, document: { _type: "export", __export_format: 4, __export_source: "shango", resources: @resources })
      end

      def add_children(folder, parent_id)
        @tree.folders_in(folder).each do |child|
          @resources << { _id: id(child), _type: "request_group", parentId: parent_id, name: child.name, authentication: auth_for(child), metaSortKey: sort_key }
          add_children(child, id(child))
        end
        @tree.requests_in(folder).each { |api_request| @resources << request_resource(api_request, parent_id) }
      end

      def request_resource(api_request, parent_id)
        {
          _id: id(api_request), _type: "request", parentId: parent_id, name: api_request.name, method: api_request.http_method, url: convert(api_request.url),
          parameters: rows(api_request.query_params), headers: rows(api_request.headers), body: body_for(api_request), authentication: auth_for(api_request),
          description: api_request.description.to_s, settingFollowRedirects: api_request.setting(:follow_redirects) ? "global" : "off", metaSortKey: sort_key
        }
      end

      def add_environments(workspace_id)
        return if @environments.empty?

        base = { _id: "env_base_#{workspace_id}", _type: "environment", parentId: workspace_id, name: "Base Environment", data: {} }
        @resources << base
        @environments.each do |environment|
          data = environment.variables.select(&:enabled).to_h { |variable| [variable.key, convert(@credentials.variable_value(variable))] }
          @resources << { _id: id(environment), _type: "environment", parentId: base[:_id], name: environment.name, data: }
        end
      end

      def rows(rows)
        rows.map { |row| { name: row["key"], value: convert(row["value"]), disabled: !row["enabled"], description: row["description"].presence }.compact }
      end

      def body_for(api_request)
        case api_request.body_type
        when "json", "xml", "text" then { mimeType: mime(api_request.body_type), text: convert(api_request.body) }
        when "form_urlencoded" then { mimeType: "application/x-www-form-urlencoded", params: rows(api_request.body_form) }
        when "multipart" then { mimeType: "multipart/form-data", params: api_request.body_form.map { |row| form_row(row) } }
        when "graphql" then { mimeType: "application/graphql", text: { query: convert(api_request.body), variables: api_request.graphql_variables.presence }.compact.to_json }
        else {}
        end
      end

      def mime(type)
        { "json" => "application/json", "xml" => "application/xml", "text" => "text/plain" }.fetch(type)
      end

      def form_row(row)
        file = row["type"] == "file"
        { name: row["key"], disabled: !row["enabled"] }.merge(file ? { type: "file", fileName: row["value"] } : { value: convert(row["value"]) })
      end

      def auth_for(record)
        return {} if record.auth_type == AuthConfigurable::INHERIT

        config = @credentials.auth_config(record).transform_values { |value| convert(value) }
        case record.auth_type
        when "none" then { type: "none" }
        when "basic", "digest" then { type: record.auth_type, username: config["username"], password: config["password"] }
        when "bearer" then { type: "bearer", token: config["token"], prefix: config["prefix"].presence || "Bearer" }
        when "api_key" then { type: "apikey", key: config["key"], value: config["value"], addTo: config["add_to"] == "query" ? "queryParams" : "header" }
        when "aws_sigv4" then { type: "iam", accessKeyId: config["access_key"], secretAccessKey: config["secret_key"], sessionToken: config["session_token"], region: config["region"], service: config["service"] }
        when "oauth2" then oauth2(config)
        else {}
        end
      end

      def oauth2(config)
        return {} unless GRANTS.include?(config["grant_type"])

        {
          type: "oauth2", grantType: config["grant_type"], accessTokenUrl: config["token_url"], authorizationUrl: config["authorization_url"], clientId: config["client_id"],
          clientSecret: config["client_secret"], username: config["username"], password: config["password"], scope: config["scope"]
        }
      end

      # Shango's `{{name}}` is Insomnia's `{{ _.name }}`; the dynamic helpers keep their own names.
      def convert(text)
        return text unless text.is_a?(String) && text.include?("{{")

        text.gsub(Imports::VariableConverter::PATTERN) do
          name = Regexp.last_match(1)
          next "{{ $randomUUID }}" if name == "$guid"

          name.start_with?("$") ? "{{ #{name} }}" : "{{ _.#{name} }}"
        end
      end

      def id(record)
        "#{record.class.name.underscore}_#{record.id}"
      end

      def sort_key
        @order += 1
      end
    end
  end
end
