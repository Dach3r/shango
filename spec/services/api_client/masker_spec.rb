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

  describe "encoded secrets" do
    subject(:masker) { described_class.new(["p@ss word/1", "tok?en=="]) }

    it "masks base64, url-safe base64 and percent-encoded forms", :aggregate_failures do
      secret = "p@ss word/1"
      text = [Base64.strict_encode64(secret), Base64.urlsafe_encode64(secret, padding: false), CGI.escape(secret), ERB::Util.url_encode(secret)].join(" | ")

      expect(masker.string(text)).to eq(Array.new(4) { described_class::MASK }.join(" | "))
    end

    it "still masks the plain secret" do
      expect(masker.string("echo tok?en== done")).to eq("echo #{described_class::MASK} done")
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
