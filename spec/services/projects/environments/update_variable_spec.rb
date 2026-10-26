require "rails_helper"

RSpec.describe Projects::Environments::UpdateVariable do
  let(:variable) { create(:variable, value: "old") }

  it "updates the value", :aggregate_failures do
    result = described_class.call(variable:, value: "new")

    expect(result).to be_success
    expect(variable.reload.value).to eq("new")
  end

  it "fails when the record is invalid" do
    variable.key = ""

    expect(described_class.call(variable:, value: "new")).to be_failure
  end
end
