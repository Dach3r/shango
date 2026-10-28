module Projects
  module Invitations
    # Invites an email address to the project. A new invitation replaces any open one for the same address, so inviting
    # again doubles as resending. Result#data[:delivered] tells whether the email went out; either way the caller can
    # hand the link to the invitee through Invitation#token, which exists only on the invitation just created.
    class Create
      include Serviceable

      DELIVERY_ERRORS = [Net::SMTPError, Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError].freeze

      def initialize(project:, inviter:, email:, role:)
        @project = project
        @inviter = inviter
        @email = email
        @role = role
      end

      private

      def perform
        invitation = @project.invitations.new(email: @email, role: @role, inviter: @inviter)
        return Result.failure(invitation, error: :invalid) unless invitation.valid?
        return Result.failure(invitation, error: :already_member) if @project.users.exists?(email: invitation.email)

        Invitation.transaction do
          @project.invitations.open.where(email: invitation.email).update_all(revoked_at: Time.current)
          invitation.save!
        end
        Result.success(invitation, delivered: deliver(invitation))
      rescue ActiveRecord::RecordNotUnique
        Result.failure(invitation, error: :duplicate)
      end

      def deliver(invitation)
        return false unless Shango::Mailing.enabled?

        InvitationMailer.invite(invitation, invitation.token).deliver_now
        true
      rescue *DELIVERY_ERRORS => error
        Rails.logger.warn("[invitations] email to #{invitation.id} not delivered: #{error.class}")
        false
      end
    end
  end
end
