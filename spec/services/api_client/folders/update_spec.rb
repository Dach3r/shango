require "rails_helper"

RSpec.describe ApiClient::Folders::Update do
  let(:folder) { create(:folder, name: "Old") }

  it "updates the name and auth", :aggregate_failures do
    result = described_class.call(folder:, attributes: { name: "New", auth_type: "bearer", auth_config: { "token" => "abc" } })

    expect(result).to be_success
    expect(folder.reload).to have_attributes(name: "New", auth_type: "bearer")
  end

  it "updates the assertions and extractors" do
    described_class.call(folder:, attributes: { assertions: [{ source: "status", operator: "equals", expected: "200" }], extractors: [{ source: "status", variable: "code" }] })

    expect(folder.reload).to have_attributes(assertions: [include("source" => "status")], extractors: [include("variable" => "code")])
  end

  it "fails when the folder is invalid" do
    expect(described_class.call(folder:, attributes: { name: "" })).to be_failure
  end

  describe "edge cases" do
    it "ignores parent and collection changes", :aggregate_failures do
      other = create(:folder)
      described_class.call(folder:, attributes: { name: "New", parent_id: other.id, collection_id: other.collection_id })

      expect(folder.reload).to have_attributes(name: "New", parent_id: nil)
      expect(folder.collection_id).not_to eq(other.collection_id)
    end

    it "fails for a blank name" do
      expect(described_class.call(folder:, attributes: { name: " " })).to be_failure
    end
  end
end
