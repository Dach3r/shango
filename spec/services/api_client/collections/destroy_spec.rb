require "rails_helper"

RSpec.describe ApiClient::Collections::Destroy do
  let(:collection) { create(:collection) }

  it "destroys the collection" do
    result = described_class.call(collection:)

    expect(result).to be_success
    expect(Collection.exists?(collection.id)).to be(false)
  end

  it "fails when destroy is halted" do
    allow(collection).to receive(:destroy).and_return(false)

    expect(described_class.call(collection:)).to be_failure
  end
end
