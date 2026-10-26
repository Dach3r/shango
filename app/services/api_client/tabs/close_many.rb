module ApiClient
  module Tabs
    # Closes several tabs at once; untouched drafts are discarded and drafts with edits stay open so no work is lost.
    class CloseMany
      include Serviceable

      def initialize(api_requests:, user:)
        @api_requests = api_requests
        @user = user
      end

      private

      def perform
        discarded, others = @api_requests.partition(&:untouched_draft?)
        discarded.each(&:destroy)
        saved = others.reject(&:draft?)
        RequestTab.where(user: @user, api_request_id: saved.map(&:id)).destroy_all
        Result.success(@api_requests)
      end
    end
  end
end
