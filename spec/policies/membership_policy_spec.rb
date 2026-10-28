require "rails_helper"

RSpec.describe MembershipPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:owner) { owner_membership(project:) }
  let(:member) { member_membership(project:) }

  describe "#update?" do
    it "lets members change their own preferences" do
      expect(described_class.new(member, member)).to be_update
    end

    it "keeps them from changing someone else's, even an owner's", :aggregate_failures do
      expect(described_class.new(owner, member)).not_to be_update
      expect(described_class.new(member, owner)).not_to be_update
    end
  end

  describe "roles and removal" do
    it "lets owners manage the other members", :aggregate_failures do
      policy = described_class.new(owner, member)

      expect(policy).to be_change_role
      expect(policy).to be_revoke
    end

    it "lets an owner change their own role but not remove themselves", :aggregate_failures do
      policy = described_class.new(owner, owner)

      expect(policy).to be_change_role
      expect(policy).not_to be_revoke
    end

    it "keeps members from managing anyone", :aggregate_failures do
      policy = described_class.new(member, owner)

      expect(policy).not_to be_change_role
      expect(policy).not_to be_revoke
    end

    it "never reaches other projects", :aggregate_failures do
      policy = described_class.new(owner, create(:membership))

      expect(policy).not_to be_change_role
      expect(policy).not_to be_revoke
    end
  end

  describe "#leave?" do
    it "is for the member's own membership only", :aggregate_failures do
      expect(described_class.new(member, member)).to be_leave
      expect(described_class.new(member, owner)).not_to be_leave
    end
  end
end
