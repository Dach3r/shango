module Projects
  module Members
    # Promotes a member to owner or demotes an owner to member. The project's last owner cannot be demoted.
    class ChangeRole
      include Serviceable

      def initialize(membership:, role:, actor:)
        @membership = membership
        @actor = actor
        @role = role.to_s
      end

      private

      def perform
        return Result.failure(@membership, error: :invalid_role) unless Membership.roles.key?(@role)

        @membership.transaction do
          @membership.project.lock!
          from = @membership.role
          if @membership.update(role: @role)
            record_event(from) if from != @role
            next Result.success(@membership)
          end

          Result.failure(@membership, error: :last_owner)
        end
      end

      def record_event(from)
        AuditEvents::Record.call(project: @membership.project, kind: :role_changed, actor: @actor, target: @membership.user, from:, to: @role)
      end
    end
  end
end
