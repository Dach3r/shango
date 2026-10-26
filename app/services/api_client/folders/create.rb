module ApiClient
  module Folders
    class Create
      include Serviceable

      def initialize(collection:, attributes:)
        @collection = collection
        @attributes = attributes.to_h.symbolize_keys
      end

      private

      def perform
        folder = @collection.folders.new(@attributes.slice(:name, :parent_id))
        Auth::Assign.call(record: folder, auth_type: @attributes[:auth_type].presence || AuthConfigurable::INHERIT, auth_config: @attributes[:auth_config].to_h)
        folder.save ? Result.success(folder) : Result.failure(folder)
      end
    end
  end
end
