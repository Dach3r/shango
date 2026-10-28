module ApiClient
  module Drafts
    # Deletes drafts nobody touched for `days` days (their tabs and latest responses go with them), and the latest
    # responses of saved requests untouched that long.
    class Prune
      include Serviceable

      def initialize(days:)
        @days = days
      end

      private

      def perform
        cutoff = @days.days.ago
        RequestDraft.stale(cutoff).in_batches(of: 1000).delete_all
        LatestExecution.stale(cutoff).in_batches(of: 1000).delete_all
      end
    end
  end
end
