require "rails_helper"

RSpec.describe Project do
  subject(:project) { build(:project) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:icon) }
  it { is_expected.to validate_inclusion_of(:icon).in_array(described_class::ICONS) }
  it { is_expected.to have_many(:invitations).dependent(:destroy) }
  it { is_expected.to have_many(:audit_events).dependent(:destroy) }

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

  describe "name" do
    it "rejects whitespace only" do
      expect(build(:project, name: "   ")).not_to be_valid
    end

    it "does not need to be unique" do
      create(:project, name: "Acme")

      expect(build(:project, name: "Acme")).to be_valid
    end
  end

  describe ".create_with_owner edge cases" do
    let(:user) { create(:user) }

    it "rejects an unknown icon without creating anything", :aggregate_failures do
      created = described_class.create_with_owner(user, name: "Acme", icon: "nope")

      expect(created).not_to be_persisted
      expect(described_class.count).to eq(0)
      expect(Membership.count).to eq(0)
    end

    it "rolls the project back when the membership cannot be created", :aggregate_failures do
      allow_any_instance_of(Membership).to receive(:save!).and_raise(ActiveRecord::RecordInvalid) # rubocop:disable RSpec/AnyInstance

      created = described_class.create_with_owner(user, name: "Acme", icon: "rocket")

      expect(created).to be_a(described_class)
      expect(described_class.count).to eq(0)
    end
  end

  describe "dependents" do
    it "removes memberships, environments, cookies and their children on destroy", :aggregate_failures do
      environment = create(:environment)
      project = environment.project
      create(:membership, project:)
      create(:variable, environment:)
      create(:cookie, project:, environment:)

      project.destroy

      expect([Membership, Environment, Variable, Cookie].map(&:count)).to eq([0, 0, 0, 0])
    end

    it "does not touch other projects" do
      keep = create(:environment)
      create(:project).destroy

      expect(Environment.exists?(keep.id)).to be(true)
    end
  end
end
