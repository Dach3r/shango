module Projects
  module Invitations
    # Withdraws an invitation that was neither accepted nor revoked yet; its link stops working.
    class Revoke
      include Serviceable

      def initialize(invitation:)
        @invitation = invitation
      end

      private

      def perform
        return Result.failure(@invitation, error: :unavailable) if @invitation.accepted? || @invitation.revoked?

        @invitation.update!(revoked_at: Time.current)
        Result.success(@invitation)
      end
    end
  end
end
