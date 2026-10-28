module Projects
  class InvitationsController < AuthenticatedController
    before_action { authorize current_project, :manage_members? }

    def create
      attributes = params.expect(invitation: %i[email role])
      result = Invitations::Create.call(project: current_project, inviter: current_user, email: attributes[:email], role: attributes[:role])
      return redirect_to(members_path, alert: t(".failed.#{result.error}"), status: :see_other) if result.failure?

      session[:invitation_link] = invitation_acceptance_url(token: result.record.token)
      redirect_to members_path, notice: t(result.data[:delivered] ? ".sent" : ".created", email: result.record.email), status: :see_other
    end

    def destroy
      invitation = current_project.invitations.open.find(params[:id])
      Invitations::Revoke.call(invitation:)
      redirect_to members_path, notice: t(".revoked", email: invitation.email), status: :see_other
    end
  end
end
