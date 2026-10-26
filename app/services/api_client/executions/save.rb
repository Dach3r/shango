module ApiClient
  module Executions
    # Moves a pending (cached) execution into the request's history and prunes the oldest entries.
    class Save
      include Serviceable

      def initialize(api_request:, user:, id:)
        @api_request = api_request
        @user = user
        @id = id
      end

      private

      def perform
        execution = RequestExecution.pending(@id)
        return Result.failure(error: :expired) unless owned?(execution)

        execution.save!
        Rails.cache.delete(RequestExecution.pending_key(@id))
        prune
        Result.success(execution)
      end

      def owned?(execution)
        execution && execution.api_request_id == @api_request.id && execution.user_id == @user.id
      end

      def prune
        stale = @api_request.request_executions.recent.offset(RequestExecution::KEEP_PER_REQUEST).pluck(:id)
        RequestExecution.where(id: stale).delete_all if stale.any?
      end
    end
  end
end
