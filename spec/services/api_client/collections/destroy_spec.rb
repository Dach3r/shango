require "rails_helper"

RSpec.describe ApiClient::Collections::Destroy do
  let(:collection) { create(:collection) }

  it "destroys the collection" do
    result = described_class.call(collection:)

    expect(result).to be_success
    expect(Collection.exists?(collection.id)).to be(false)
  end

  it "records who deleted it" do
    actor = create(:user)
    described_class.call(collection:, actor:)

    expect(AuditEvent.sole).to have_attributes(kind: "collection_deleted", actor:, metadata: include("name" => collection.name))
  end

  it "fails when destroy is halted", :aggregate_failures do
    allow(collection).to receive(:destroy).and_return(false)

    expect(described_class.call(collection:)).to be_failure
    expect(AuditEvent.count).to eq(0)
  end
end
