module ApiClient
  module Exports
    # Shango's own JSON: everything the app stores for a collection, so importing it back loses nothing but the secrets left out.
    class Shango
      include Serviceable

      VERSION = 1

      def initialize(collection:, environments:, credentials:, progress: nil)
        @collection = collection
        @environments = environments
        @credentials = credentials
        @tree = Tree.new(collection, progress:)
      end

      private

      def perform
        document = { shango: { version: VERSION }, collection: node(@collection, nil).merge(description: @collection.description.to_s) }
        document[:environments] = @environments.map { |environment| environment_document(environment) } if @environments.any?
        Result.success(nil, document:)
      end

      def node(record, folder)
        {
          name: record.name, auth_type: record.auth_type, auth_config: @credentials.auth_config(record),
          folders: @tree.folders_in(folder).map { |child| node(child, child) },
          requests: @tree.requests_in(folder).map { |api_request| request_document(api_request) }
        }
      end

      def request_document(api_request)
        api_request.slice(:name, :http_method, :url, :description, :body_type, :body, :graphql_variables, :query_params, :headers, :body_form, :auth_type, :settings)
                   .merge(auth_config: @credentials.auth_config(api_request))
      end

      def environment_document(environment)
        { name: environment.name, variables: environment.variables.map { |variable| { key: variable.key, value: @credentials.variable_value(variable), secret: variable.secret, enabled: variable.enabled } } }
      end
    end
  end
end
