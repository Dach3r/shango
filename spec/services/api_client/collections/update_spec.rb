require "rails_helper"

RSpec.describe ApiClient::Collections::Update do
  let(:collection) { create(:collection, name: "Old") }

  it "updates the allowed attributes" do
    result = described_class.call(collection:, attributes: { name: "New", description: "Text", auth_type: "bearer" })

    expect(result).to be_success
    expect(collection.reload).to have_attributes(name: "New", description: "Text", auth_type: "none")
  end

  it "updates the assertions and extractors" do
    described_class.call(collection:, attributes: { assertions: [{ source: "status", operator: "lt", expected: "500" }], extractors: [{ source: "status", variable: "code" }] })

    expect(collection.reload).to have_attributes(assertions: [include("operator" => "lt")], extractors: [include("variable" => "code")])
  end

  it "updates the scripts" do
    described_class.call(collection:, attributes: { pre_request_script: "// a", post_response_script: "// b" })

    expect(collection.reload).to have_attributes(pre_request_script: "// a", post_response_script: "// b")
  end

  it "records who changed it, and nothing when nothing changed", :aggregate_failures do
    actor = create(:user)
    described_class.call(collection:, attributes: { name: "New" }, actor:)
    described_class.call(collection:, attributes: { name: "New" }, actor:)

    expect(AuditEvent.sole).to have_attributes(kind: "collection_updated", actor:, metadata: include("name" => "New"))
  end

  it "fails when the collection is invalid", :aggregate_failures do
    result = described_class.call(collection:, attributes: { name: "" })

    expect(result).to be_failure
    expect(AuditEvent.count).to eq(0)
  end
end
