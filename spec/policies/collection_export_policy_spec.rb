require "rails_helper"

RSpec.describe CollectionExportPolicy, type: :policy do
  let(:project) { create(:project) }
  let(:member) { member_membership(project:) }
  let(:record) { create(:collection_export, project:, user: member.user) }

  it "lets the member who asked for it see and download it", :aggregate_failures do
    expect(described_class.new(member, record)).to be_show
    expect(described_class.new(member, record)).to be_download
  end

  it "keeps other members and other projects out", :aggregate_failures do
    expect(described_class.new(member_membership(project:), record)).not_to be_show
    expect(described_class.new(owner_membership(project:), record)).not_to be_download
    expect(described_class.new(member_membership, record)).not_to be_show
  end
end
