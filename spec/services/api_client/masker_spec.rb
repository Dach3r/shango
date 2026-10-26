require "rails_helper"

RSpec.describe ApiClient::Masker do
  subject(:masker) { described_class.new(["secret", "secret-long", "ab", nil, "secret"]) }

  describe "#string" do
    it "masks longest secrets first", :aggregate_failures do
      expect(masker.string("a secret-long b secret")).to eq("a #{described_class::MASK} b #{described_class::MASK}")
      expect(masker.string("ab")).to eq("ab")
    end

    it "returns blank text untouched", :aggregate_failures do
      expect(masker.string(nil)).to be_nil
      expect(masker.string("")).to eq("")
    end
  end

  describe "#request_headers" do
    it "hides sensitive headers and masks other values" do
      result = masker.request_headers([["Authorization", "Bearer secret"], ["X-Other", "secret"]])

      expect(result).to eq([["Authorization", described_class::MASK], ["X-Other", described_class::MASK]])
    end

    it "keeps non sensitive values" do
      expect(masker.request_headers([["Accept", "*/*"]])).to eq([["Accept", "*/*"]])
    end
  end

  describe "#response_headers" do
    it "masks values" do
      expect(masker.response_headers([["Set-Cookie", "id=secret"]])).to eq([["Set-Cookie", "id=#{described_class::MASK}"]])
    end
  end
end
