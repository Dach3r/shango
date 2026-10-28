module ApiClient
  module Exports
    # Renders a collection (and, on demand, the project's environments) in the format another API client reads.
    # Result#data carries the file name, content type and content; formats whose environments live in their own
    # files (Postman) come back as a ZIP.
    class Export
      include Serviceable

      EXPORTERS = { postman: Postman, insomnia: Insomnia, openapi: Openapi, shango: Shango }.freeze
      FORMATS = EXPORTERS.keys.freeze
      JSON_TYPE = "application/json".freeze

      def initialize(collection:, format:, include_environments: false, include_credentials: false, on_progress: nil)
        @collection = collection
        @format = format.to_s.to_sym
        @include_environments = include_environments
        @include_credentials = include_credentials
        @on_progress = on_progress
      end

      private

      def perform
        return Result.failure(error: I18n.t("workbench.exports.errors.unknown_format")) unless FORMATS.include?(@format)

        progress = Progress.new(total: @collection.api_requests.count, &@on_progress)
        built = EXPORTERS.fetch(@format).call(collection: @collection, environments:, credentials: Credentials.new(include: @include_credentials), progress:)
        progress.update(Progress::BUILD_SHARE + 5)
        @format == :postman ? deliver_postman(built.data) : file("#{@format}.json", built.data[:document])
      end

      # OpenAPI reads the environments only to find the server URL, so it always gets them.
      def environments
        return [] unless @include_environments || @format == :openapi

        @collection.project.environments.ordered.includes(:variables).to_a
      end

      def deliver_postman(data)
        return file("postman_collection.json", data[:collection]) if data[:environments].empty?

        files = { "#{slug}.postman_collection.json" => pretty(data[:collection]) }
        data[:environments].each_with_index { |document, index| files["#{index + 1}-#{document[:name].parameterize.presence || "environment"}.postman_environment.json"] = pretty(document) }
        Result.success(nil, filename: "#{slug}.zip", content_type: "application/zip", content: Zip.build(files))
      end

      def file(suffix, document)
        Result.success(nil, filename: "#{slug}.#{suffix}", content_type: JSON_TYPE, content: pretty(document))
      end

      def pretty(document)
        JSON.pretty_generate(document)
      end

      def slug
        @collection.name.parameterize.presence || "collection"
      end
    end
  end
end
