module Projects
  module Members
    # Promotes a member to owner or demotes an owner to member. The project's last owner cannot be demoted.
    class ChangeRole
      include Serviceable

      def initialize(membership:, role:)
        @membership = membership
        @role = role.to_s
      end

      private

      def perform
        return Result.failure(@membership, error: :invalid_role) unless Membership.roles.key?(@role)

        @membership.transaction do
          @membership.project.lock!
          next Result.success(@membership) if @membership.update(role: @role)

          Result.failure(@membership, error: :last_owner)
        end
      end
    end
  end
end
