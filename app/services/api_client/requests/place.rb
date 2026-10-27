module ApiClient
  module Requests
    # Moves a draft into a collection (optionally a folder), last among its siblings.
    class Place
      include Serviceable

      def initialize(api_request:, collection:, folder: nil)
        @api_request = api_request
        @collection = collection
        @folder = folder
      end

      private

      def perform
        @api_request.assign_attributes(collection: @collection, folder: @folder, user: nil)
        @api_request.position = @api_request.siblings.where.not(id: @api_request.id).maximum(:position).to_i + 1
        return Result.failure(@api_request) unless @api_request.save

        Result.success(@api_request)
      end
    end
  end
end
