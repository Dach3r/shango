module ApiClient
  module Requests
    # Applies submitted editor attributes (and auth settings) to a request in memory, without saving it.
    class Assign
      include Serviceable

      def initialize(api_request:, attributes:)
        @api_request = api_request
        @attributes = attributes.to_h.symbolize_keys
      end

      private

      def perform
        @api_request.assign_attributes(@attributes.slice(*Create::ATTRIBUTES))
        Auth::Assign.call(record: @api_request, auth_type: @attributes[:auth_type], auth_config: @attributes[:auth_config].to_h)
        @api_request
      end
    end
  end
end
