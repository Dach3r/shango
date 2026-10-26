module ApiClient
  module Collections
    class Update
      include Serviceable

      def initialize(collection:, attributes:)
        @collection = collection
        @attributes = attributes.to_h.symbolize_keys
      end

      private

      def perform
        @collection.assign_attributes(@attributes.slice(:name, :description))
        @collection.save ? Result.success(@collection) : Result.failure(@collection)
      end
    end
  end
end
