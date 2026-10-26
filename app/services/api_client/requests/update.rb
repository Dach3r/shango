module ApiClient
  module Requests
    class Update
      include Serviceable

      def initialize(api_request:, attributes:, uploads: {}, binary_upload: nil)
        @api_request = api_request
        @attributes = attributes.to_h.symbolize_keys
        @uploads = uploads
        @binary_upload = binary_upload
      end

      private

      def perform
        @api_request.assign_attributes(@attributes.slice(*Create::ATTRIBUTES))
        Auth::Assign.call(record: @api_request, auth_type: @attributes[:auth_type], auth_config: @attributes[:auth_config].to_h)
        AttachUploads.call(api_request: @api_request, uploads: @uploads, binary_upload: @binary_upload)
        @api_request.save ? Result.success(@api_request) : Result.failure(@api_request)
      end
    end
  end
end
