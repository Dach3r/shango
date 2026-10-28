module Projects
  module Members
    # Ends a membership (kept as history) and records who did it; a member revoking themselves is leaving. The project's
    # last owner cannot be revoked.
    class Revoke
      include Serviceable

      def initialize(membership:, actor:)
        @membership = membership
        @actor = actor
      end

      private

      def perform
        @membership.transaction do
          @membership.project.lock!
          if @membership.update(revoked_at: Time.current)
            record_event
            next Result.success(@membership)
          end

          Result.failure(@membership, error: :last_owner)
        end
      end

      def record_event
        kind = @actor.id == @membership.user_id ? :member_left : :member_revoked
        AuditEvents::Record.call(project: @membership.project, kind:, actor: @actor, target: @membership.user)
      end
    end
  end
end
