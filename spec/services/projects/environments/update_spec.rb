require "rails_helper"

RSpec.describe Projects::Environments::Update do
  let(:environment) { create(:environment) }

  it "updates the environment", :aggregate_failures do
    result = described_class.call(environment:, attributes: { name: "Staging" })

    expect(result).to be_success
    expect(environment.reload.name).to eq("Staging")
  end

  it "records who changed it, and nothing when nothing changed", :aggregate_failures do
    actor = create(:user)
    described_class.call(environment:, attributes: { name: "Staging" }, actor:)
    described_class.call(environment:, attributes: { name: "Staging" }, actor:)

    expect(AuditEvent.sole).to have_attributes(kind: "environment_updated", actor:, metadata: include("name" => "Staging"))
  end

  it "fails with invalid attributes", :aggregate_failures do
    expect(described_class.call(environment:, attributes: { name: "" })).to be_failure
    expect(AuditEvent.count).to eq(0)
  end
end
