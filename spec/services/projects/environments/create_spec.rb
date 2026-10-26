require "rails_helper"

RSpec.describe Projects::Environments::Create do
  let(:project) { create(:project) }

  it "creates an environment with ordered variables", :aggregate_failures do
    result = described_class.call(project:, attributes: { name: "Prod", variables_attributes: [{ key: "A", value: "1" }] })

    expect(result).to be_success
    expect(result.record).to have_attributes(name: "Prod", project:)
    expect(result.record.variables.map(&:key)).to eq(["A"])
  end

  it "fails with invalid attributes", :aggregate_failures do
    result = described_class.call(project:, attributes: { name: "" })

    expect(result).to be_failure
    expect(result.record.errors).to include(:name)
  end
end
