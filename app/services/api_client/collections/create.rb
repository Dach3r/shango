module ApiClient
  module Collections
    class Create
      include Serviceable

      def initialize(project:, attributes:)
        @project = project
        @attributes = attributes.to_h.symbolize_keys
      end

      private

      def perform
        collection = @project.collections.new(@attributes.slice(:name, :description))
        collection.save ? Result.success(collection) : Result.failure(collection)
      end
    end
  end
end
