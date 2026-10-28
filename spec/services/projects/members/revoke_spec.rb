require "rails_helper"

RSpec.describe Projects::Members::Revoke do
  let(:project) { create(:project) }
  let!(:owner) { create(:membership, :owner, project:) }

  it "revokes a member and keeps the record as history", :aggregate_failures do
    member = create(:membership, project:)
    result = described_class.call(membership: member)

    expect(result).to be_success
    expect(member.reload).not_to be_active
    expect(Membership.exists?(member.id)).to be(true)
  end

  it "refuses to revoke the last owner", :aggregate_failures do
    result = described_class.call(membership: owner)

    expect(result).to be_failure
    expect(result.error).to eq(:last_owner)
    expect(owner.reload).to be_active
  end

  it "lets one of several owners go" do
    create(:membership, :owner, project:)

    expect(described_class.call(membership: owner)).to be_success
  end
end
