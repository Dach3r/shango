require "rails_helper"

RSpec.describe Projects::Environments::CreateVariable do
  let(:environment) { create(:environment) }

  it "creates the variable in the environment", :aggregate_failures do
    result = described_class.call(environment:, key: "locale", value: "es")

    expect(result).to be_success
    expect(environment.variables.find_by(key: "locale").value).to eq("es")
  end

  it "reuses and enables a disabled variable with the same key", :aggregate_failures do
    variable = create(:variable, environment:, key: "locale", enabled: false)
    result = described_class.call(environment:, key: "locale", value: "es")

    expect(result.record).to eq(variable)
    expect(variable.reload).to have_attributes(enabled: true, value: "es")
  end

  it "fails with an invalid key" do
    expect(described_class.call(environment:, key: "bad key", value: "x")).to be_failure
  end
end
