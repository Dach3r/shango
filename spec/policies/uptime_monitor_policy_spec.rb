require "rails_helper"

RSpec.describe UptimeMonitorPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:owner) { owner_membership(project:) }
  let(:member) { member_membership(project:) }
  let(:other_member) { member_membership(project:) }
  let(:record) { create(:uptime_monitor, project:, creator: member.user) }

  it "lets every member of the project see and create" do
    expect(described_class.new(other_member, record)).to have_attributes(show?: true, create?: true, new?: true)
  end

  it "lets the creator and an owner change, run, pause and delete it", :aggregate_failures do
    [member, owner].each do |membership|
      expect(described_class.new(membership, record)).to have_attributes(update?: true, edit?: true, run?: true, pause?: true, destroy?: true)
    end
  end

  it "keeps other members from changing it" do
    expect(described_class.new(other_member, record)).to have_attributes(update?: false, run?: false, pause?: false, destroy?: false)
  end

  it "never reaches a monitor of another project" do
    expect(described_class.new(owner_membership, record)).to have_attributes(show?: false, create?: false, update?: false)
  end
end
