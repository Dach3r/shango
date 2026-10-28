module ApiClient
  module Drafts
    # Ids of the given saved requests that have pending edits for the user.
    class UnsavedIds
      include Serviceable

      def initialize(requests:, user:)
        @requests = requests
        @user = user
      end

      private

      def perform
        @user.request_drafts.where(api_request_id: @requests.select(&:persisted?).map(&:id)).pluck(:api_request_id)
      end
    end
  end
end
