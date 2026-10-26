require "rails_helper"

RSpec.describe Project do
  subject(:project) { build(:project) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:icon) }
  it { is_expected.to validate_inclusion_of(:icon).in_array(described_class::ICONS) }

  describe ".active" do
    it "excludes archived projects" do
      active = create(:project)
      create(:project, :archived)

      expect(described_class.active).to contain_exactly(active)
    end
  end

  describe ".create_with_owner" do
    let(:user) { create(:user) }

    it "creates the project and its owner membership", :aggregate_failures do
      created = described_class.create_with_owner(user, name: "Acme", icon: "rocket")

      expect(created).to be_persisted
      expect(created.memberships.first).to have_attributes(user:, role: "owner")
    end

    it "returns the invalid project without membership", :aggregate_failures do
      created = described_class.create_with_owner(user, name: "", icon: "rocket")

      expect(created).not_to be_persisted
      expect(Membership.count).to eq(0)
    end
  end
end
