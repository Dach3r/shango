require "rails_helper"

RSpec.describe Projects::Invitations::Accept do
  let(:project) { create(:project) }
  let(:user) { create(:user, email: "invitee@example.com") }
  let(:invitation) { create(:invitation, project:, email: "invitee@example.com", role: "owner") }

  it "adds the user to the project with the invited role", :aggregate_failures do
    result = described_class.call(invitation:, user:)

    expect(result).to be_success
    expect(result.record).to have_attributes(user:, project:, role: "owner")
    expect(invitation.reload).to be_accepted
  end

  it "accepts regardless of email case" do
    user.update_column(:email, "Invitee@Example.com")

    expect(described_class.call(invitation:, user:)).to be_success
  end

  it "does not duplicate an existing membership", :aggregate_failures do
    existing = create(:membership, project:, user:)
    result = described_class.call(invitation:, user:)

    expect(result.record).to eq(existing)
    expect(project.memberships.where(user:).count).to eq(1)
    expect(invitation.reload).to be_accepted
  end

  it "re-adds someone whose membership was revoked", :aggregate_failures do
    create(:membership, :revoked, project:, user:)
    result = described_class.call(invitation:, user:)

    expect(result).to be_success
    expect(result.record).to be_active
  end

  it "refuses other people's accounts", :aggregate_failures do
    result = described_class.call(invitation:, user: create(:user))

    expect(result.error).to eq(:wrong_account)
    expect(invitation.reload).not_to be_accepted
    expect(project.memberships.count).to eq(0)
  end

  it "refuses invitations that are used, revoked, expired or for an archived project", :aggregate_failures do
    [create(:invitation, :accepted, project:, email: "invitee@example.com"), create(:invitation, :revoked, project:, email: "other1@example.com"),
     create(:invitation, :expired, project:, email: "other2@example.com"), create(:invitation, project: create(:project, :archived), email: "invitee@example.com")].each do |unusable|
      expect(described_class.call(invitation: unusable, user:).error).to eq(:unavailable)
    end
  end

  it "works only once", :aggregate_failures do
    described_class.call(invitation:, user:)

    expect(described_class.call(invitation:, user:).error).to eq(:unavailable)
  end
end
