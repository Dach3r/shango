module Projects
  module Members
    # Ends a membership (kept as history). The project's last owner cannot be revoked.
    class Revoke
      include Serviceable

      def initialize(membership:)
        @membership = membership
      end

      private

      def perform
        @membership.transaction do
          @membership.project.lock!
          next Result.success(@membership) if @membership.update(revoked_at: Time.current)

          Result.failure(@membership, error: :last_owner)
        end
      end
    end
  end
end
