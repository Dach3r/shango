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
        Auth::Assign.call(record: @collection, auth_type: @attributes[:auth_type], auth_config: @attributes[:auth_config].to_h)
        @collection.save ? Result.success(@collection) : Result.failure(@collection)
      end
    end
  end
end
