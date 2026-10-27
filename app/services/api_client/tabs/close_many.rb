module ApiClient
  module Tabs
    # Closes several tabs at once; drafts are discarded, saved requests only lose their tab and unsaved edits.
    # Callers confirm with the user first when edits would be lost.
    class CloseMany
      include Serviceable

      def initialize(api_requests:, user:)
        @api_requests = api_requests
        @user = user
      end

      private

      def perform
        drafts, saved = @api_requests.partition(&:draft?)
        drafts.each(&:destroy)
        RequestTab.where(user: @user, api_request_id: saved.map(&:id)).destroy_all
        saved.each { |api_request| Requests::Stash.clear(api_request:, user: @user) }
        Result.success(@api_requests)
      end
    end
  end
end
