module ApiClient
  module Requests
    # Saves any pending edits (a new draft only keeps them as a draft) and sends the request. Inline (see Shango::ExecutionMode) Result#record is the unsaved
    # RequestExecution (see Dispatch); in async mode the send is queued and Result#data[:run_id] is what the browser
    # polls (Executions::RunState, RunRequestJob). On invalid edits it is a failure carrying the request.
    class Run
      include Serviceable

      def initialize(api_request:, environment:, user:, attributes: {}, uploads: {}, binary_upload: nil)
        @api_request = api_request
        @environment = environment
        @user = user
        @attributes = attributes
        @uploads = uploads
        @binary_upload = binary_upload
      end

      private

      def perform
        uploaded = @uploads.any? || @binary_upload.present?
        if @attributes.present?
          saved = save
          return saved if saved.failure?
        end

        return enqueue(uploaded) if Shango::ExecutionMode.async?

        Dispatch.call(api_request: @api_request, environment: @environment, user: @user)
      end

      # A saved request takes the edits for good (and drops its pending draft); a new one only keeps them as a draft.
      def save
        return save_draft if @api_request.draft?

        saved = Update.call(api_request: @api_request, attributes: @attributes, uploads: @uploads, binary_upload: @binary_upload)
        return saved if saved.failure?

        Drafts::Discard.call(api_request: @api_request, user: @user)
        @api_request.reload
        saved
      end

      def save_draft
        Assign.call(api_request: @api_request, attributes: @attributes)
        return Result.failure(@api_request) unless @api_request.valid?

        saved = Drafts::Save.call(api_request: @api_request, user: @user, attributes: @attributes)
        @api_request.errors.add(:base, :draft_too_large) if saved.failure?
        saved.success? ? Result.success(@api_request) : Result.failure(@api_request)
      end

      def enqueue(uploaded)
        run_id = SecureRandom.uuid
        Executions::RunState.start(run_id, user_id: @user.id, api_request_id: @api_request.id, uploaded:)
        RunRequestJob.perform_later(@user.id, @api_request.id, @environment&.id, run_id)
        Result.success(nil, run_id:)
      end
    end
  end
end
