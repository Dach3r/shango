require "rails_helper"

RSpec.describe CollectionRunPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:starter) { member_membership(project:) }
  let(:run) { create(:collection_run, project:, user: starter.user) }

  it "lets any member of the project see and start runs", :aggregate_failures do
    other = member_membership(project:)

    expect(described_class.new(other, run)).to be_show
    expect(described_class.new(other, run)).to be_create
  end

  it "keeps other projects out", :aggregate_failures do
    outsider = member_membership

    expect(described_class.new(outsider, run)).not_to be_show
    expect(described_class.new(outsider, run)).not_to be_create
    expect(described_class.new(outsider, run)).not_to be_cancel
  end

  it "lets only who started an active run, or an owner, cancel it", :aggregate_failures do
    expect(described_class.new(starter, run)).to be_cancel
    expect(described_class.new(owner_membership(project:), run)).to be_cancel
    expect(described_class.new(member_membership(project:), run)).not_to be_cancel
  end

  it "has nothing to cancel once it finished" do
    run = create(:collection_run, :completed, project:, user: starter.user)

    expect(described_class.new(starter, run)).not_to be_cancel
  end
end
