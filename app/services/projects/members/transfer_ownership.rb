module Projects
  module Members
    # Hands the project over: the target becomes an owner and the current owner steps down to member.
    class TransferOwnership
      include Serviceable

      def initialize(from:, to:)
        @from = from
        @to = to
      end

      private

      def perform
        return Result.failure(@to, error: :invalid_target) unless valid_target?

        @from.transaction do
          @from.project.lock!
          @to.update!(role: :owner)
          @from.update!(role: :member)
          AuditEvents::Record.call(project: @from.project, kind: :ownership_transferred, actor: @from.user, target: @to.user)
          Result.success(@to)
        end
      end

      def valid_target?
        @from.owner? && @to.active? && @from.id != @to.id && @from.project_id == @to.project_id
      end
    end
  end
end
