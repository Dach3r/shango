require "rails_helper"

RSpec.describe Projects::Invitations::Revoke do
  it "revokes an open invitation", :aggregate_failures do
    invitation = create(:invitation)

    expect(described_class.call(invitation:)).to be_success
    expect(invitation.reload).to be_revoked
  end

  it "does nothing for invitations that are already accepted or revoked", :aggregate_failures do
    [create(:invitation, :accepted), create(:invitation, :revoked)].each do |invitation|
      expect(described_class.call(invitation:).error).to eq(:unavailable)
    end
  end
end
