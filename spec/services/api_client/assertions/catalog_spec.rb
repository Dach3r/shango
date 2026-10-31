require "rails_helper"

RSpec.describe ApiClient::Assertions::Catalog do
  it "lists the sources", :aggregate_failures do
    expect(described_class.sources).to eq(%w[status header json body time size])
    expect(described_class::OPERATORS.values.flatten).to all(be_a(String))
  end

  it "accepts only the operators of a source", :aggregate_failures do
    expect(described_class.valid_assertion?("json", "length")).to be(true)
    expect(described_class.valid_assertion?("status", "length")).to be(false)
    expect(described_class.valid_assertion?("nope", "equals")).to be(false)
  end

  it "knows which sources take a target and which operators take a value", :aggregate_failures do
    expect(described_class.targeted?("json")).to be(true)
    expect(described_class.targeted?("status")).to be(false)
    expect(described_class.expects_value?("equals")).to be(true)
    expect(described_class.expects_value?("exists")).to be(false)
  end
end
