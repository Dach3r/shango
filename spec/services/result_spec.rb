require "rails_helper"

RSpec.describe Result do
  describe ".success" do
    subject(:result) { described_class.success(:record, token: "t") }

    it "wraps the record and data", :aggregate_failures do
      expect(result).to be_success
      expect(result).not_to be_failure
      expect(result.record).to eq(:record)
      expect(result.data).to eq(token: "t")
      expect(result.error).to be_nil
    end
  end

  describe ".failure" do
    subject(:result) { described_class.failure(:record, error: "boom", extra: 1) }

    it "wraps the record, error and data", :aggregate_failures do
      expect(result).to be_failure
      expect(result).not_to be_success
      expect(result.error).to eq("boom")
      expect(result.data).to eq(extra: 1)
    end
  end
end
