require "rails_helper"

RSpec.describe ApiClient::Collections::Update do
  let(:collection) { create(:collection, name: "Old") }

  it "updates the allowed attributes" do
    result = described_class.call(collection:, attributes: { name: "New", description: "Text", auth_type: "bearer" })

    expect(result).to be_success
    expect(collection.reload).to have_attributes(name: "New", description: "Text", auth_type: "none")
  end

  it "fails when the collection is invalid" do
    result = described_class.call(collection:, attributes: { name: "" })

    expect(result).to be_failure
  end
end
