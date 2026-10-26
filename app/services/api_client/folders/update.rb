module ApiClient
  module Folders
    class Update
      include Serviceable

      def initialize(folder:, attributes:)
        @folder = folder
        @attributes = attributes.to_h.symbolize_keys
      end

      private

      def perform
        @folder.assign_attributes(@attributes.slice(:name))
        Auth::Assign.call(record: @folder, auth_type: @attributes[:auth_type], auth_config: @attributes[:auth_config].to_h)
        @folder.save ? Result.success(@folder) : Result.failure(@folder)
      end
    end
  end
end
