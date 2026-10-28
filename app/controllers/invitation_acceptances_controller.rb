# The page an invitation link opens. Signed-out visitors are sent to sign in or sign up first and come back here.
class InvitationAcceptancesController < ApplicationController
  layout "devise"

  before_action :authenticate_user!
  throttle :invitation_acceptance, by: -> { current_user.id }
  before_action :set_invitation

  def show
    @state = state
  end

  def create
    return redirect_to(root_path, alert: t(".failed.unavailable"), status: :see_other) unless @invitation

    result = Projects::Invitations::Accept.call(invitation: @invitation, user: current_user)
    return redirect_to(root_path, alert: t(".failed.#{result.error}"), status: :see_other) if result.failure?

    current_user.update!(current_membership_id: result.record.id)
    redirect_to root_path, notice: t(".joined", project: @invitation.project.name), status: :see_other
  end

  private

  def set_invitation
    @invitation = Invitation.find_by_token(params[:token])
  end

  def state
    return :invalid unless @invitation&.usable? && @invitation.project.archived_at.nil?

    current_user.email.casecmp?(@invitation.email) ? :ready : :wrong_account
  end
end
