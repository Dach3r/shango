require "rails_helper"

RSpec.describe Membership do
  subject(:membership) { create(:membership) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to define_enum_for(:role).with_values(member: "member", owner: "owner").backed_by_column_of_type(:string) }

  describe "uniqueness" do
    it "rejects a second active membership for the same user and project", :aggregate_failures do
      duplicate = build(:membership, user: membership.user, project: membership.project)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to include(:user_id)
    end

    it "allows re-adding after a revocation" do
      membership.revoke!

      expect(build(:membership, user: membership.user, project: membership.project)).to be_valid
    end
  end

  describe "#active?" do
    it "is true until revoked", :aggregate_failures do
      expect(membership).to be_active
      membership.revoke!
      expect(membership).not_to be_active
    end
  end

  describe ".active" do
    it "excludes revoked memberships" do
      create(:membership, :revoked)

      expect(described_class.active).to contain_exactly(membership)
    end
  end
end
