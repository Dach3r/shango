require "rails_helper"

RSpec.describe ProjectPolicy, type: :policy do
  let(:project) { create(:project) }

  it "lets members of the project use it", :aggregate_failures do
    policy = described_class.new(member_membership(project:), project)

    expect(policy).to be_use
    expect(policy).to be_import
  end

  it "keeps other projects out", :aggregate_failures do
    policy = described_class.new(owner_membership, project)

    expect(policy).not_to be_use
    expect(policy).not_to be_import
  end

  describe "#manage_members?" do
    it "is for the owners of the project", :aggregate_failures do
      expect(described_class.new(owner_membership(project:), project)).to be_manage_members
      expect(described_class.new(member_membership(project:), project)).not_to be_manage_members
    end

    it "does not reach other projects" do
      expect(described_class.new(owner_membership, project)).not_to be_manage_members
    end
  end
end
