module ApiClient
  module Imports
    # Insomnia exports: v4 (flat `resources` linked by parentId) and v5 (nested `collection` YAML/JSON).
    class Insomnia
      include Serviceable

      OAUTH_GRANTS = { "client_credentials" => "client_credentials", "password" => "password", "authorization_code" => "authorization_code" }.freeze

      def initialize(data:)
        @data = data
        @warnings = []
      end

      private

      def perform
        tree = @data["_type"] == "export" ? from_resources : from_collection
        Result.success(tree.merge(warnings: @warnings))
      end

      def from_resources
        @resources = Array(@data["resources"]).select { |resource| resource.is_a?(Hash) }
        workspaces = @resources.select { |resource| resource["_type"] == "workspace" }
        workspaces = [{ "_id" => nil, "name" => "Insomnia import" }] if workspaces.empty?
        trees = workspaces.map do |workspace|
          collection = Support.folder(name: workspace["name"], **children_of(workspace["_id"])).slice(:name, :folders, :requests)
          { collections: [collection.merge(description: workspace["description"].presence)], environments: resource_environments(workspace) }
        end
        { collections: trees.flat_map { |tree| tree[:collections] }, environments: trees.flat_map { |tree| tree[:environments] } }
      end

      def children_of(parent_id)
        children = @resources.select { |resource| resource["parentId"] == parent_id }.sort_by { |resource| resource["metaSortKey"].to_f }
        folders = children.select { |resource| resource["_type"] == "request_group" }.map do |group|
          Support.folder(name: group["name"], **auth_attributes(group["authentication"]), **children_of(group["_id"]).slice(:folders, :requests))
        end
        requests = children.select { |resource| resource["_type"] == "request" }.map { |resource| request_from(resource) }
        { folders:, requests: }
      end

      def resource_environments(workspace)
        base = @resources.find { |resource| resource["_type"] == "environment" && resource["parentId"] == workspace["_id"] }
        return [] unless base

        subs = @resources.select { |resource| resource["_type"] == "environment" && resource["parentId"] == base["_id"] }
        environments_from(workspace["name"], base["data"], subs)
      end

      def from_collection
        collection = Support.folder(name: @data["name"], **walk(@data["collection"])).slice(:name, :folders, :requests)
        environments = @data["environments"].is_a?(Hash) ? environments_from(@data["name"], @data["environments"]["data"], Array(@data["environments"]["subEnvironments"])) : []
        { collections: [collection], environments: }
      end

      def walk(nodes)
        folders = []
        requests = []
        Array(nodes).each do |node|
          next unless node.is_a?(Hash)

          if node.key?("children")
            folders << Support.folder(name: node["name"], **auth_attributes(node["authentication"]), **walk(node["children"]))
          else
            requests << request_from(node)
          end
        end
        { folders:, requests: }
      end

      def environments_from(name, base_data, subs)
        base = flatten(base_data)
        return (base.empty? ? [] : [Support.environment(name:, variables: variables(base))]) if subs.empty?

        subs.map { |sub| Support.environment(name: sub["name"], variables: variables(base.merge(flatten(sub["data"])))) }
      end

      def flatten(data, prefix = nil)
        return {} unless data.is_a?(Hash)

        data.each_with_object({}) do |(key, value), result|
          path = [prefix, key].compact.join(".")
          value.is_a?(Hash) ? result.merge!(flatten(value, path)) : result[path] = value.is_a?(Array) ? value.to_json : value.to_s
        end
      end

      def variables(pairs)
        pairs.map { |key, value| Support.variable(key, value) }
      end

      def request_from(node)
        body = node["body"].is_a?(Hash) ? node["body"] : {}
        query = rows(node["parameters"])
        attributes = Support.request(
          name: node["name"], http_method: node["method"] || "GET", url: node["url"], query_params: query, headers: rows(node["headers"]),
          description: node["description"].presence, **body_attributes(body, node["name"]), **auth_attributes(node["authentication"])
        )
        VariableConverter.request(attributes, @warnings)
      end

      def rows(entries)
        Array(entries).filter_map do |entry|
          Support.row(entry["name"], entry["value"], enabled: !entry["disabled"], description: entry["description"]) if entry["name"].present?
        end
      end

      def body_attributes(body, name)
        return {} if body.empty?

        mime = body["mimeType"].to_s
        if mime.include?("graphql") then graphql(body["text"])
        elsif mime.include?("x-www-form-urlencoded") then { body_type: "form_urlencoded", body_form: rows(body["params"]) }
        elsif mime.include?("multipart") then { body_type: "multipart", body_form: form_rows(body["params"], name) }
        elsif mime.include?("octet-stream") then file_body(name)
        elsif body["text"].present? then { body_type: Support.body_type_for(mime), body: body["text"] }
        else {}
        end
      end

      def graphql(text)
        parsed = JSON.parse(text.to_s)
        { body_type: "graphql", body: parsed["query"], graphql_variables: parsed["variables"]&.then { |variables| variables.is_a?(String) ? variables : variables.to_json } }
      rescue JSON::ParserError
        { body_type: "graphql", body: text }
      end

      def form_rows(params, name)
        Array(params).filter_map do |param|
          next if param["name"].blank?

          file = param["type"] == "file"
          add_warning(:file_body, name:) if file
          Support.row(param["name"], file ? File.basename(param["fileName"].to_s) : param["value"], enabled: !param["disabled"]).merge("type" => file ? "file" : "text")
        end
      end

      def file_body(name)
        add_warning(:file_body, name:)
        {}
      end

      def auth_attributes(auth)
        return {} unless auth.is_a?(Hash) && auth["type"].present? && auth["disabled"] != true

        mapped =
          case auth["type"]
          when "none" then AuthMapper.call("none", {}, @warnings)
          when "basic", "digest" then AuthMapper.call(auth["type"], auth.slice("username", "password"), @warnings)
          when "bearer" then AuthMapper.call("bearer", { "token" => auth["token"], "prefix" => auth["prefix"].presence || "Bearer" }, @warnings)
          when "apikey" then AuthMapper.call("api_key", { "key" => auth["key"], "value" => auth["value"], "add_to" => auth["addTo"] == "queryParams" ? "query" : "header" }, @warnings)
          when "iam" then AuthMapper.call("aws_sigv4", { "access_key" => auth["accessKeyId"], "secret_key" => auth["secretAccessKey"], "session_token" => auth["sessionToken"], "region" => auth["region"], "service" => auth["service"] }, @warnings)
          when "oauth2" then oauth2(auth)
          else AuthMapper.call(auth["type"], {}, @warnings)
          end
        mapped.slice(:auth_type, :auth_config)
      end

      def oauth2(auth)
        grant = OAUTH_GRANTS[auth["grantType"]]
        return AuthMapper.call(auth["grantType"] || "oauth2_implicit", {}, @warnings) unless grant

        AuthMapper.call("oauth2", {
          "grant_type" => grant, "token_url" => auth["accessTokenUrl"], "authorization_url" => auth["authorizationUrl"], "client_id" => auth["clientId"],
          "client_secret" => auth["clientSecret"], "username" => auth["username"], "password" => auth["password"], "scope" => auth["scope"]
        }, @warnings)
      end

      def add_warning(key, **options)
        @warnings << I18n.t("workbench.imports.warnings.#{key}", **options)
      end
    end
  end
end
