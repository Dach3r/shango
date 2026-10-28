module Projects
  class MembersController < AuthenticatedController
    before_action :set_member, only: %i[update destroy]

    def index
      authorize current_project, :use?
      @members = current_project.memberships.active.includes(:user).sort_by { |member| [member.user.full_name.downcase, member.created_at] }
      return unless policy(current_project).manage_members?

      @invitations = current_project.invitations.open.order(created_at: :desc)
      @invitation_link = session.delete(:invitation_link)
    end

    def update
      result = Members::ChangeRole.call(membership: @member, role: params.expect(member: [:role])[:role], actor: current_user)
      return redirect_to(members_path, notice: t(".updated", name: @member.user.full_name), status: :see_other) if result.success?

      redirect_to members_path, alert: t(".failed.#{result.error}"), status: :see_other
    end

    def destroy
      result = Members::Revoke.call(membership: @member, actor: current_user)
      return redirect_to(members_path, notice: t(".revoked", name: @member.user.full_name), status: :see_other) if result.success?

      redirect_to members_path, alert: t(".failed"), status: :see_other
    end

    private

    def set_member
      @member = current_project.memberships.active.find(params[:id])
      authorize @member, action_name == "update" ? :change_role? : :revoke?
    end
  end
end
