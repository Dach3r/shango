require "rails_helper"

RSpec.describe Projects::Environments::Update do
  let(:environment) { create(:environment) }

  it "updates the environment", :aggregate_failures do
    result = described_class.call(environment:, attributes: { name: "Staging" })

    expect(result).to be_success
    expect(environment.reload.name).to eq("Staging")
  end

  it "fails with invalid attributes" do
    expect(described_class.call(environment:, attributes: { name: "" })).to be_failure
  end
end
