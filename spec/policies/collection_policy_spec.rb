require "rails_helper"

RSpec.describe CollectionPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:owner) { owner_membership(project:) }
  let(:member) { member_membership(project:) }
  let(:other_member) { member_membership(project:) }
  let(:record) { create(:collection, project:, creator: member.user) }

  it "lets every member of the project see and create", :aggregate_failures do
    policy = described_class.new(other_member, record)

    expect(policy).to be_show
    expect(policy).to be_create
    expect(policy).to be_new
  end

  it "lets the creator change and delete it", :aggregate_failures do
    policy = described_class.new(member, record)

    expect(policy).to be_update
    expect(policy).to be_edit
    expect(policy).to be_destroy
  end

  it "lets an owner change and delete it", :aggregate_failures do
    policy = described_class.new(owner, record)

    expect(policy).to be_update
    expect(policy).to be_destroy
  end

  it "keeps other members from changing or deleting it", :aggregate_failures do
    policy = described_class.new(other_member, record)

    expect(policy).not_to be_update
    expect(policy).not_to be_destroy
  end

  it "leaves records without a creator to the owners", :aggregate_failures do
    legacy = create(:collection, project:)

    expect(described_class.new(member, legacy)).not_to be_update
    expect(described_class.new(owner, legacy)).to be_update
  end

  it "denies everything across projects", :aggregate_failures do
    policy = described_class.new(owner_membership, record)

    expect(policy).not_to be_show
    expect(policy).not_to be_create
    expect(policy).not_to be_update
  end
end
