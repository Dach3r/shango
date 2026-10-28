require "rails_helper"

RSpec.describe FolderPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:owner) { owner_membership(project:) }
  let(:member) { member_membership(project:) }
  let(:collection) { create(:collection, project:, creator: member.user) }
  let(:folder) { create(:folder, collection:) }

  it "lets the collection's creator and the owners manage it", :aggregate_failures do
    [member, owner].each do |membership|
      policy = described_class.new(membership, folder)

      expect(policy).to be_show
      expect(policy).to be_create
      expect(policy).to be_update
      expect(policy).to be_destroy
    end
  end

  it "lets other members look but not change", :aggregate_failures do
    policy = described_class.new(member_membership(project:), folder)

    expect(policy).to be_show
    expect(policy).not_to be_create
    expect(policy).not_to be_update
    expect(policy).not_to be_destroy
  end
end
