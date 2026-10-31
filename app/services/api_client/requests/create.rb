module ApiClient
  module Requests
    class Create
      include Serviceable

      ATTRIBUTES = %i[name http_method url description folder_id body_type body graphql_variables query_params headers body_form settings assertions extractors pre_request_script post_response_script].freeze

      def initialize(collection:, attributes:, uploads: {}, binary_upload: nil)
        @collection = collection
        @attributes = attributes.to_h.symbolize_keys
        @uploads = uploads
        @binary_upload = binary_upload
      end

      private

      def perform
        api_request = @collection.api_requests.new(@attributes.slice(*ATTRIBUTES))
        Auth::Assign.call(record: api_request, auth_type: @attributes[:auth_type].presence || AuthConfigurable::INHERIT, auth_config: @attributes[:auth_config].to_h)
        return Result.failure(api_request) unless api_request.save

        AttachUploads.call(api_request:, uploads: @uploads, binary_upload: @binary_upload)
        api_request.save
        Result.success(api_request)
      end
    end
  end
end
