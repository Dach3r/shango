class InvitationMailer < ApplicationMailer
  def invite(invitation, token)
    @project = invitation.project
    @inviter = invitation.inviter
    @url = invitation_acceptance_url(token:)
    @expires_at = invitation.expires_at

    mail to: invitation.email, subject: t(".subject", project: @project.name)
  end
end
