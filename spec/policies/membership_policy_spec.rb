require "rails_helper"

RSpec.describe MembershipPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:membership) { member_membership(project:) }

  it "lets members change their own preferences" do
    expect(described_class.new(membership, membership)).to be_update
  end

  it "keeps them from changing someone else's, even an owner's", :aggregate_failures do
    owner = owner_membership(project:)

    expect(described_class.new(owner, membership)).not_to be_update
    expect(described_class.new(membership, owner)).not_to be_update
  end
end
