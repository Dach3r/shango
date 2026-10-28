module ApiClient
  module Imports
    # Shango's own export (see Exports::Shango). Result#record is the normalized tree (see Import).
    class Shango
      include Serviceable

      def initialize(data:)
        @data = data
        @warnings = []
      end

      private

      def perform
        collection = node(@data["collection"]).merge(description: @data.dig("collection", "description").presence)
        environments = Array(@data["environments"]).map { |environment| Support.environment(name: environment["name"], variables: variables(environment["variables"])) }
        Result.success({ collections: [collection], environments:, warnings: @warnings })
      end

      def node(entry)
        folder = Support.folder(name: entry["name"], **AuthMapper.call(entry["auth_type"], entry["auth_config"], @warnings))
        folder.merge(folders: Array(entry["folders"]).map { |child| node(child) }, requests: Array(entry["requests"]).map { |request| request_from(request) })
      end

      def request_from(entry)
        auth = AuthMapper.call(entry["auth_type"], entry["auth_config"], @warnings)
        Support.request(
          name: entry["name"], http_method: entry["http_method"], url: entry["url"], query_params: Array(entry["query_params"]), headers: Array(entry["headers"]),
          body_type: entry["body_type"], body: entry["body"], body_form: Array(entry["body_form"]), graphql_variables: entry["graphql_variables"],
          settings: entry["settings"].to_h, description: entry["description"].presence, **auth
        )
      end

      def variables(entries)
        Array(entries).map { |entry| Support.variable(entry["key"], entry["value"], secret: entry["secret"], enabled: entry["enabled"]) }
      end
    end
  end
end
