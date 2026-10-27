require "rails_helper"

RSpec.describe ApiClient::Folders::Create do
  let(:collection) { create(:collection) }
  let(:parent) { create(:folder, collection:) }

  it "creates a root folder inheriting auth by default" do
    result = described_class.call(collection:, attributes: { name: "Users" })

    expect(result).to be_success
    expect(result.record).to have_attributes(name: "Users", parent_id: nil, auth_type: "inherit")
  end

  it "creates a nested folder with its own auth" do
    result = described_class.call(
      collection:,
      attributes: { name: "Users", parent_id: parent.id, auth_type: "bearer", auth_config: { "token" => "abc" } }
    )

    expect(result.record).to have_attributes(parent:, auth_type: "bearer")
  end

  it "fails when the folder is invalid" do
    expect(described_class.call(collection:, attributes: { name: "" })).to be_failure
  end

  describe "edge cases" do
    let(:collection) { create(:collection) }

    it "fails for a parent that does not exist" do
      expect(described_class.call(collection:, attributes: { name: "X", parent_id: SecureRandom.uuid })).to be_failure
    end

    it "fails for a parent of another collection" do
      expect(described_class.call(collection:, attributes: { name: "X", parent_id: create(:folder).id })).to be_failure
    end

    it "appends the folder after its siblings", :aggregate_failures do
      first = described_class.call(collection:, attributes: { name: "A" }).record
      second = described_class.call(collection:, attributes: { name: "B" }).record

      expect([first.position, second.position]).to eq([1, 2])
    end

    it "numbers siblings per parent", :aggregate_failures do
      parent = create(:folder, collection:)
      create(:folder, collection:, parent:)
      nested = described_class.call(collection:, attributes: { name: "C", parent_id: parent.id }).record

      expect(nested.position).to eq(2)
    end

    it "allows duplicate and unicode names", :aggregate_failures do
      create(:folder, collection:, name: "Ünï 🚀")

      expect(described_class.call(collection:, attributes: { name: "Ünï 🚀" })).to be_success
    end
  end
end
