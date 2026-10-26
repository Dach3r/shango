module ApiClient
  module Folders
    class Destroy
      include Serviceable

      def initialize(folder:)
        @folder = folder
      end

      private

      def perform
        @folder.destroy ? Result.success(@folder) : Result.failure(@folder)
      end
    end
  end
end
