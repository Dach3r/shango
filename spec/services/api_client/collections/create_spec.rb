require "rails_helper"

RSpec.describe ApiClient::Collections::Create do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  it "creates a collection in the project" do
    result = described_class.call(project:, creator: user, attributes: { name: "Billing", description: "Docs", position: 9 })

    expect(result).to be_success
    expect(result.record).to have_attributes(project:, creator: user, name: "Billing", description: "Docs", position: 1)
    expect(AuditEvent.sole).to have_attributes(kind: "collection_created", actor: user, project:, metadata: include("name" => "Billing"))
  end

  it "fails when the collection is invalid" do
    result = described_class.call(project:, creator: user, attributes: { name: "" })

    expect(result).to be_failure
    expect(result.record.errors[:name]).to be_present
  end
end
