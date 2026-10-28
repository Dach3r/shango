require "rails_helper"

RSpec.describe InvitationMailer do
  let(:inviter) { create(:user, first_name: "Grace", last_name: "Hopper") }
  let(:project) { create(:project, name: "Acme") }
  let(:invitation) { create(:invitation, project:, inviter:, email: "new@example.com") }
  let(:mail) { described_class.invite(invitation, invitation.token) }

  it "is addressed to the invitee", :aggregate_failures do
    expect(mail.to).to eq(["new@example.com"])
    expect(mail.subject).to eq(I18n.t("invitation_mailer.invite.subject", project: "Acme"))
  end

  it "names the inviter and links to the acceptance page", :aggregate_failures do
    body = mail.body.parts.map(&:decoded).join

    expect(body).to include("Grace Hopper", "Acme", "http://example.com/invitation_acceptance?token=#{invitation.token}")
  end

  it "works when the inviter's account is gone", :aggregate_failures do
    invitation.update!(inviter: nil)
    body = mail.body.parts.map(&:decoded).join

    expect(body).to include(I18n.t("invitation_mailer.invite.body", project: "Acme"))
    expect(body).not_to include("Grace Hopper")
  end
end
