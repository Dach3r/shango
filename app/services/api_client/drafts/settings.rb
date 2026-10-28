module ApiClient
  module Drafts
    # Keeps the settings of a new draft (saved requests persist theirs straight away, see Requests::UpdateSettings).
    class Settings
      include Serviceable

      def initialize(api_request:, user:, settings:)
        @api_request = api_request
        @user = user
        @settings = settings.to_h.stringify_keys
      end

      private

      def perform
        draft = @user.request_drafts.where(api_request_id: nil).find(@api_request.id)
        data = draft.data
        draft.data = data.merge("settings" => data.fetch("settings", {}).merge(@settings))
        draft.save ? Result.success(draft) : Result.failure(draft)
      end
    end
  end
end
