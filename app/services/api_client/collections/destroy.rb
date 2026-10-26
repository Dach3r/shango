module ApiClient
  module Collections
    class Destroy
      include Serviceable

      def initialize(collection:)
        @collection = collection
      end

      private

      def perform
        @collection.destroy ? Result.success(@collection) : Result.failure(@collection)
      end
    end
  end
end
