module Projects
  module Invitations
    # Turns an invitation into a membership for the signed-in user. The invitation must still be usable and addressed to
    # the user's own email; someone who already belongs to the project just has it marked as accepted.
    class Accept
      include Serviceable

      def initialize(invitation:, user:)
        @invitation = invitation
        @user = user
      end

      private

      def perform
        @invitation.transaction do
          @invitation.lock!
          next Result.failure(@invitation, error: :unavailable) unless usable?
          next Result.failure(@invitation, error: :wrong_account) unless @user.email.casecmp?(@invitation.email)

          membership = @user.memberships.active.find_by(project: @invitation.project) || @invitation.project.memberships.create!(user: @user, role: @invitation.role)
          @invitation.update!(accepted_at: Time.current)
          AuditEvents::Record.call(project: @invitation.project, kind: :invitation_accepted, actor: @user, target: @user, email: @invitation.email, role: @invitation.role)
          Result.success(membership)
        end
      end

      def usable?
        @invitation.usable? && @invitation.project.archived_at.nil?
      end
    end
  end
end
