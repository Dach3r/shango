module ApiClient
  module Runs
    # Cancels an active run: the run and its pending items stop right away and the request in flight is aborted by the job,
    # which looks the status up between requests and while one is being read.
    class Cancel
      include Serviceable

      def initialize(run:)
        @run = run
      end

      private

      def perform
        return Result.failure(@run) unless @run.may_cancel?

        @run.cancel!
        @run.items.each { |item| item.mark_skipped! if item.may_mark_skipped? }
        Turbo::StreamsChannel.broadcast_refresh_to(@run)
        Result.success(@run)
      end
    end
  end
end
