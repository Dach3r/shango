module ApiClient
  module Requests
    # Creates a request from a pasted curl command.
    class ImportCurl
      include Serviceable

      def initialize(collection:, command:, folder_id: nil)
        @collection = collection
        @command = command
        @folder_id = folder_id.presence
      end

      private

      def perform
        parsed = Curl::Parser.call(command: @command)
        return Result.failure(nil, error: parsed.error) if parsed.failure?

        Create.call(collection: @collection, attributes: parsed.record.merge(folder_id: @folder_id))
      end
    end
  end
end
