require "rails_helper"

RSpec.describe "Members" do
  let!(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:owner_membership) { context[2] }
  let!(:member_membership) { create(:membership, project:, user: create(:user, first_name: "Grace", last_name: "Hopper")) }

  describe "GET /members" do
    it "lists the active members with their roles", :aggregate_failures do
      create(:membership, :revoked, project:, user: create(:user, first_name: "Gone", last_name: "Person"))
      get members_path

      expect(response.body).to include("Grace Hopper", "Ada Lovelace", I18n.t("projects.members.index.roles.owner"), I18n.t("projects.members.index.roles.member"))
      expect(response.body).not_to include("Gone Person")
    end

    it "offers owners the member actions and the ownership transfer", :aggregate_failures do
      get members_path

      expect(response.body).to include(I18n.t("projects.members.index.make_owner"), I18n.t("projects.members.index.remove"), I18n.t("projects.members.index.transfer.title"))
    end

    it "labels the confirmations after what they do", :aggregate_failures do
      create(:invitation, project:, email: "pending@example.com")
      get members_path

      %w[remove leave transfer.submit invitations.revoke].each do |key|
        expect(response.body).to include(%(data-confirm-label="#{I18n.t("projects.members.index.#{key}")}"))
      end
    end

    it "shows members only their own leave action", :aggregate_failures do
      sign_in member_membership.user
      member_membership.user.update!(current_membership: member_membership)
      get members_path

      expect(response.body).to include(I18n.t("projects.members.index.leave"))
      expect(response.body).not_to include(I18n.t("projects.members.index.make_owner"), I18n.t("projects.members.index.remove"), I18n.t("projects.members.index.transfer.title"))
    end

    it "hides the transfer when the owner is alone" do
      member_membership.destroy!
      get members_path

      expect(response.body).not_to include(I18n.t("projects.members.index.transfer.title"))
    end
  end

  describe "PATCH /members/:id" do
    it "promotes a member", :aggregate_failures do
      patch member_path(member_membership), params: { member: { role: "owner" } }

      expect(response).to redirect_to(members_path)
      expect(flash[:notice]).to eq(I18n.t("projects.members.update.updated", name: "Grace Hopper"))
      expect(member_membership.reload).to be_owner
    end

    it "keeps the last owner", :aggregate_failures do
      patch member_path(owner_membership), params: { member: { role: "member" } }

      expect(flash[:alert]).to eq(I18n.t("projects.members.update.failed.last_owner"))
      expect(owner_membership.reload).to be_owner
    end

    it "rejects unknown roles" do
      patch member_path(member_membership), params: { member: { role: "admin" } }

      expect(flash[:alert]).to eq(I18n.t("projects.members.update.failed.invalid_role"))
    end

    it "is owner-only", :aggregate_failures do
      sign_in member_membership.user
      member_membership.user.update!(current_membership: member_membership)
      patch member_path(member_membership), params: { member: { role: "owner" } }

      expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
      expect(member_membership.reload).to be_member
    end

    it "does not reach members of other projects" do
      patch member_path(create(:membership)), params: { member: { role: "owner" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /members/:id" do
    it "revokes the member's access", :aggregate_failures do
      delete member_path(member_membership)

      expect(response).to redirect_to(members_path)
      expect(flash[:notice]).to eq(I18n.t("projects.members.destroy.revoked", name: "Grace Hopper"))
      expect(member_membership.reload).not_to be_active
    end

    it "cannot revoke yourself, the leave action exists for that", :aggregate_failures do
      delete member_path(owner_membership)

      expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
      expect(owner_membership.reload).to be_active
    end

    it "reports a refused revocation of the last owner" do
      allow(Projects::Members::Revoke).to receive(:call).and_return(Result.failure(member_membership, error: :last_owner))
      delete member_path(member_membership)

      expect(flash[:alert]).to eq(I18n.t("projects.members.destroy.failed"))
    end

    it "is owner-only", :aggregate_failures do
      sign_in member_membership.user
      member_membership.user.update!(current_membership: member_membership)
      delete member_path(owner_membership)

      expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
      expect(owner_membership.reload).to be_active
    end
  end

  describe "POST /leave" do
    it "lets a member leave", :aggregate_failures do
      sign_in member_membership.user
      member_membership.user.update!(current_membership: member_membership)
      post leave_path

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("projects.leaves.create.left", project: project.name))
      expect(member_membership.reload).not_to be_active
    end

    it "keeps the last owner in the project", :aggregate_failures do
      post leave_path

      expect(response).to redirect_to(members_path)
      expect(flash[:alert]).to eq(I18n.t("projects.leaves.create.last_owner"))
      expect(owner_membership.reload).to be_active
    end
  end

  describe "POST /ownership_transfer" do
    it "hands the project over", :aggregate_failures do
      post ownership_transfer_path, params: { member_id: member_membership.id }

      expect(response).to redirect_to(members_path)
      expect(flash[:notice]).to eq(I18n.t("projects.ownership_transfers.create.transferred", name: "Grace Hopper"))
      expect(member_membership.reload).to be_owner
      expect(owner_membership.reload).to be_member
    end

    it "refuses other projects' members", :aggregate_failures do
      post ownership_transfer_path, params: { member_id: create(:membership).id }

      expect(response).to have_http_status(:not_found)
      expect(owner_membership.reload).to be_owner
    end

    it "reports an invalid target", :aggregate_failures do
      post ownership_transfer_path, params: { member_id: owner_membership.id }

      expect(flash[:alert]).to eq(I18n.t("projects.ownership_transfers.create.invalid"))
    end

    it "is owner-only", :aggregate_failures do
      sign_in member_membership.user
      member_membership.user.update!(current_membership: member_membership)
      post ownership_transfer_path, params: { member_id: owner_membership.id }

      expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
      expect(owner_membership.reload).to be_owner
    end
  end
end
