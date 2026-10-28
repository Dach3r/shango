module ApiClient
  module Drafts
    # Keeps the editor state of a request as a draft: the pending edits of a saved request or the whole of a new one.
    # The payload is encrypted at rest, so credentials in it are safe; uploaded files are not kept. Fails when the state is too large.
    class Save
      include Serviceable

      def initialize(api_request:, user:, attributes:)
        @api_request = api_request
        @user = user
        @attributes = attributes
      end

      private

      def perform
        draft = find_or_initialize
        data = @attributes.to_h.deep_stringify_keys
        draft.data = data.merge(draft.data.slice("settings"))
        draft.name = data["name"].presence || draft.name
        draft.http_method = data["http_method"].to_s.upcase.presence_in(ApiRequest::METHODS) || draft.http_method
        draft.save ? Result.success(draft) : Result.failure(draft)
      end

      def find_or_initialize
        if @api_request.persisted?
          @user.request_drafts.find_or_initialize_by(api_request: @api_request) do |draft|
            draft.project = @api_request.project
            draft.name = @api_request.name
            draft.data = {}
          end
        else
          @user.request_drafts.where(project: @api_request.project, api_request_id: nil).find(@api_request.id)
        end
      end
    end
  end
end
