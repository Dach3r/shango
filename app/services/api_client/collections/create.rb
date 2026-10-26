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
        Auth::Assign.call(record: collection, auth_type: @attributes[:auth_type], auth_config: @attributes[:auth_config].to_h)
        collection.save ? Result.success(collection) : Result.failure(collection)
      end
    end
  end
end
