require "rails_helper"

RSpec.describe ApplicationPolicy, type: :policy do
  subject(:policy) { described_class.new(member_membership, Object.new) }

  it "denies everything by default", :aggregate_failures do
    expect(policy).not_to be_index
    expect(policy).not_to be_show
    expect(policy).not_to be_create
    expect(policy).not_to be_update
    expect(policy).not_to be_destroy
  end

  describe "#manage?" do
    let(:project) { create(:project) }
    let(:owner) { owner_membership(project:) }
    let(:member) { member_membership(project:) }
    let(:policy_class) { Class.new(described_class) { public :manage? } }

    it "lets an owner manage records of the project, whoever created them", :aggregate_failures do
      expect(policy_class.new(owner, create(:collection, project:, creator: member.user))).to be_manage
      expect(policy_class.new(owner, create(:collection, project:))).to be_manage
    end

    it "lets a member manage only what they created", :aggregate_failures do
      expect(policy_class.new(member, create(:collection, project:, creator: member.user))).to be_manage
      expect(policy_class.new(member, create(:collection, project:, creator: owner.user))).not_to be_manage
      expect(policy_class.new(member, create(:collection, project:))).not_to be_manage
    end

    it "never reaches records of another project", :aggregate_failures do
      other = create(:collection, creator: member.user)

      expect(policy_class.new(owner, other)).not_to be_manage
      expect(policy_class.new(member, other)).not_to be_manage
    end

    it "does not manage records without project or creator", :aggregate_failures do
      expect(policy_class.new(owner, Object.new)).not_to be_manage
      expect(policy_class.new(member, Object.new)).not_to be_manage
    end
  end
end
