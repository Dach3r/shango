require "rails_helper"

RSpec.describe NotificationChannelPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:owner) { owner_membership(project:) }
  let(:member) { member_membership(project:) }
  let(:other_member) { member_membership(project:) }
  let(:record) { create(:notification_channel, project:, creator: member.user) }

  it "lets every member of the project create" do
    expect(described_class.new(other_member, record)).to have_attributes(create?: true, new?: true)
  end

  it "lets the creator and an owner change, test and delete it", :aggregate_failures do
    [member, owner].each do |membership|
      expect(described_class.new(membership, record)).to have_attributes(update?: true, edit?: true, test?: true, destroy?: true)
    end
  end

  it "keeps other members and other projects out", :aggregate_failures do
    expect(described_class.new(other_member, record)).to have_attributes(update?: false, test?: false, destroy?: false)
    expect(described_class.new(owner_membership, record)).to have_attributes(create?: false, update?: false)
  end
end
