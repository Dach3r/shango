module ApiClient
  module Tabs
    # Closes several tabs at once; new drafts are discarded, saved requests only lose their tab and pending edits.
    # Callers confirm with the user first when edits would be lost.
    class CloseMany
      include Serviceable

      def initialize(api_requests:, user:)
        @api_requests = api_requests
        @user = user
      end

      private

      def perform
        @api_requests.each { |api_request| Close.call(api_request:, user: @user) }
        Result.success(@api_requests)
      end
    end
  end
end
