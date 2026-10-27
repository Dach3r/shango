module Network
  module Checks
    # Saves a successful run to the user's history in the project and trims their oldest runs of that tool beyond
    # NetworkCheck::KEEP_PER_KIND. Failed runs (invalid input, blocked targets) are not recorded. `input` is what the user
    # typed, with `{{variables}}` unresolved, so environment values never reach the table.
    class Record
      include Serviceable

      def initialize(kind:, result:, input:, project:, user: nil, environment: nil)
        @kind = kind
        @result = result
        @input = input
        @project = project
        @user = user
        @environment = environment
      end

      private

      def perform
        return Result.failure(error: :failed_run) if @result.failure?

        digest = Digest.for(@kind, @result.data)
        check = @project.network_checks.create!(kind: @kind, user: @user, environment: @environment, target: @result.data[:host], outcome: digest.tone,
                                                input: @input.to_h.transform_values { |value| value.to_s.first(NetworkCheck::INPUT_LIMIT) }, result: Codec.dump(@kind, @result.data))
        trim
        Result.success(check)
      rescue ActiveRecord::ActiveRecordError => error
        Rails.logger.warn("[network] history not saved: #{error.class}")
        Result.failure(error: :not_saved)
      end

      def trim
        scope = @project.network_checks.where(user: @user, kind: @kind)
        NetworkCheck.where(id: scope.recent.offset(NetworkCheck::KEEP_PER_KIND).ids).delete_all
      end
    end
  end
end
