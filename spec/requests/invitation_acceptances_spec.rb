require "rails_helper"

RSpec.describe "Invitation acceptance" do
  let(:project) { create(:project, name: "Acme") }
  let(:invitation) { create(:invitation, project:, email: "invitee@example.com", role: "member") }
  let(:token) { invitation.token }
  let(:user) { create(:user, email: "invitee@example.com") }

  describe "GET /invitation_acceptance" do
    it "sends signed-out visitors to sign in and brings them back", :aggregate_failures do
      get invitation_acceptance_path(token:)

      expect(response).to redirect_to(new_user_session_path)

      post user_session_path, params: { user: { email: user.email, password: "password" } }
      expect(response).to redirect_to("http://www.example.com/invitation_acceptance?token=#{token}")
    end

    it "offers to join", :aggregate_failures do
      sign_in user
      get invitation_acceptance_path(token:)

      expect(response.body).to include(I18n.t("invitation_acceptances.show.body", project: "Acme", role: I18n.t("invitation_acceptances.show.roles.member")))
      expect(response.body).to include(I18n.t("invitation_acceptances.show.join"))
      expect(Membership.count).to eq(0)
    end

    it "tells owners-to-be which role they get" do
      invitation.update!(role: "owner")
      sign_in user
      get invitation_acceptance_path(token:)

      expect(response.body).to include(I18n.t("invitation_acceptances.show.roles.owner"))
    end

    it "explains when the account is not the invited one", :aggregate_failures do
      sign_in create(:user, email: "someone@example.com")
      get invitation_acceptance_path(token:)

      expect(response.body).to include(I18n.t("invitation_acceptances.show.wrong_account", email: "someone@example.com"), I18n.t("invitation_acceptances.show.sign_out"))
      expect(response.body).not_to include(I18n.t("invitation_acceptances.show.join"))
    end

    it "does not tell unknown, used, revoked, expired or archived apart", :aggregate_failures do
      sign_in user
      invalid = I18n.t("invitation_acceptances.show.invalid")
      [create(:invitation, :accepted, email: user.email), create(:invitation, :revoked, email: user.email), create(:invitation, :expired, email: user.email),
       create(:invitation, project: create(:project, :archived), email: user.email)].each do |unusable|
        get invitation_acceptance_path(token: unusable.token)
        expect(response.body).to include(invalid)
      end

      get invitation_acceptance_path(token: "unknown")
      expect(response.body).to include(invalid)
    end
  end

  describe "POST /invitation_acceptance" do
    before { sign_in user }

    it "joins the project and selects it", :aggregate_failures do
      post invitation_acceptance_path, params: { token: }
      membership = project.memberships.find_by!(user:)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("invitation_acceptances.create.joined", project: "Acme"))
      expect(membership).to be_member
      expect(user.reload.current_membership_id).to eq(membership.id)
    end

    it "works once", :aggregate_failures do
      post invitation_acceptance_path, params: { token: }
      post invitation_acceptance_path, params: { token: }

      expect(flash[:alert]).to eq(I18n.t("invitation_acceptances.create.failed.unavailable"))
      expect(project.memberships.count).to eq(1)
    end

    it "refuses unknown tokens", :aggregate_failures do
      post invitation_acceptance_path, params: { token: "unknown" }

      expect(flash[:alert]).to eq(I18n.t("invitation_acceptances.create.failed.unavailable"))
      expect(Membership.count).to eq(0)
    end

    it "refuses other people's accounts", :aggregate_failures do
      sign_in create(:user, email: "someone@example.com")
      post invitation_acceptance_path, params: { token: }

      expect(flash[:alert]).to eq(I18n.t("invitation_acceptances.create.failed.wrong_account"))
      expect(Membership.count).to eq(0)
    end
  end

  describe "signing up from the link" do
    it "lands on the invitation instead of the new project form", :aggregate_failures do
      get invitation_acceptance_path(token:)
      post user_registration_path, params: { user: { first_name: "In", last_name: "Vitee", email: "invitee@example.com", password: "password", password_confirmation: "password" } }

      expect(response).to redirect_to("http://www.example.com/invitation_acceptance?token=#{token}")
    end
  end
end
