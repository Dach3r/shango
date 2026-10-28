require "rails_helper"

RSpec.describe "Invitations" do
  let!(:context) { sign_in_with_project(create(:user, :confirmed)) }
  let(:project) { context[1] }
  let(:member_user) { create(:user) }

  def invite(email: "new@example.com", role: "member")
    post invitations_path, params: { invitation: { email:, role: } }
  end

  before { ActionMailer::Base.deliveries.clear }

  describe "POST /invitations" do
    it "creates the invitation and shows its link once", :aggregate_failures do
      expect { invite }.to change(Invitation, :count).by(1)

      expect(response).to redirect_to(members_path)
      expect(flash[:notice]).to eq(I18n.t("projects.invitations.create.created", email: "new@example.com"))
      token = project.invitations.last.token_digest

      follow_redirect!
      link = response.body[%r{http://www.example.com/invitation_acceptance\?token=([\w-]+)}, 1]
      expect(Invitation.digest(link)).to eq(token)

      get members_path
      expect(response.body).not_to include("invitation_acceptance?token=")
    end

    it "emails the link when SMTP is configured", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_SMTP_ADDRESS" => "smtp.example.com"))
      invite

      expect(flash[:notice]).to eq(I18n.t("projects.invitations.create.sent", email: "new@example.com"))
      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end

    it "invites owners too" do
      invite(role: "owner")

      expect(project.invitations.last).to be_owner
    end

    it "reports the reasons it refuses", :aggregate_failures do
      invite(email: "nope")
      expect(flash[:alert]).to eq(I18n.t("projects.invitations.create.failed.invalid"))

      create(:membership, project:, user: create(:user, email: "member@example.com"))
      invite(email: "member@example.com")
      expect(flash[:alert]).to eq(I18n.t("projects.invitations.create.failed.already_member"))
      expect(Invitation.count).to eq(0)
    end

    it "is owner-only", :aggregate_failures do
      membership = create(:membership, project:, user: member_user)
      member_user.update!(current_membership: membership)
      sign_in member_user

      expect { invite }.not_to change(Invitation, :count)
      expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
    end
  end

  describe "DELETE /invitations/:id" do
    it "revokes the invitation", :aggregate_failures do
      invitation = create(:invitation, project:, email: "new@example.com")
      delete invitation_path(invitation)

      expect(response).to redirect_to(members_path)
      expect(flash[:notice]).to eq(I18n.t("projects.invitations.destroy.revoked", email: "new@example.com"))
      expect(invitation.reload).to be_revoked
    end

    it "does not reach other projects' invitations" do
      delete invitation_path(create(:invitation))

      expect(response).to have_http_status(:not_found)
    end

    it "does not reach closed invitations" do
      delete invitation_path(create(:invitation, :revoked, project:))

      expect(response).to have_http_status(:not_found)
    end

    it "is owner-only", :aggregate_failures do
      invitation = create(:invitation, project:)
      membership = create(:membership, project:, user: member_user)
      member_user.update!(current_membership: membership)
      sign_in member_user
      delete invitation_path(invitation)

      expect(flash[:alert]).to eq(I18n.t("authorization.forbidden"))
      expect(invitation.reload).not_to be_revoked
    end
  end

  describe "the pending list on the members page" do
    it "lists open invitations to owners, with expired ones marked", :aggregate_failures do
      create(:invitation, project:, email: "open@example.com")
      create(:invitation, :expired, project:, email: "old@example.com")
      create(:invitation, :revoked, project:, email: "revoked@example.com")
      get members_path

      expect(response.body).to include("open@example.com", "old@example.com", I18n.t("projects.members.index.invitations.expired"))
      expect(response.body).not_to include("revoked@example.com")
    end

    it "keeps the invitations from members", :aggregate_failures do
      create(:invitation, project:, email: "open@example.com")
      membership = create(:membership, project:, user: member_user)
      member_user.update!(current_membership: membership)
      sign_in member_user
      get members_path

      expect(response.body).not_to include("open@example.com", I18n.t("projects.members.index.invitations.title"))
    end
  end
end
