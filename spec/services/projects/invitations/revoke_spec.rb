require "rails_helper"

RSpec.describe Projects::Invitations::Revoke do
  it "revokes an open invitation", :aggregate_failures do
    invitation = create(:invitation)

    expect(described_class.call(invitation:, actor: create(:user))).to be_success
    expect(invitation.reload).to be_revoked
  end

  it "does nothing for invitations that are already accepted or revoked", :aggregate_failures do
    [create(:invitation, :accepted), create(:invitation, :revoked)].each do |invitation|
      expect(described_class.call(invitation:, actor: create(:user)).error).to eq(:unavailable)
    end
  end

  it "records who revoked it", :aggregate_failures do
    actor = create(:user)
    invitation = create(:invitation, email: "new@example.com")
    described_class.call(invitation:, actor:)

    expect(AuditEvent.last).to have_attributes(project: invitation.project, kind: "invitation_revoked", actor:, metadata: include("email" => "new@example.com"))
  end

  it "records nothing for closed invitations" do
    expect { described_class.call(invitation: create(:invitation, :revoked), actor: create(:user)) }.not_to change(AuditEvent, :count)
  end
end
