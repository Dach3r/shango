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

    it "treats secrets as literal text, not patterns", :aggregate_failures do
      masker = described_class.new(["a.c", "(x+)", "\\1\\2", "$&$1"])

      expect(masker.string("abc a.c (x+) xx \\1\\2 $&$1")).to eq("abc #{described_class::MASK} #{described_class::MASK} xx #{described_class::MASK} #{described_class::MASK}")
    end

    it "masks every occurrence, across lines and inside larger words", :aggregate_failures do
      expect(masker.string("secret\nxsecretx\nsecretsecret")).to eq("#{described_class::MASK}\nx#{described_class::MASK}x\n#{described_class::MASK * 2}")
    end

    it "masks unicode secrets inside binary and invalid byte strings", :aggregate_failures do
      masker = described_class.new(["pässwörd"])

      expect(masker.string("café pässwörd".b)).to eq("café #{described_class::MASK}")
      expect(masker.string("bad\xFF pässwörd")).to eq("bad\uFFFD #{described_class::MASK}")
    end

    it "masks unicode secrets" do
      expect(described_class.new(["pässwörd"]).string("hi pässwörd")).to eq("hi #{described_class::MASK}")
    end

    it "masks secrets echoed back inside JSON, query strings and form bodies", :aggregate_failures do
      masker = described_class.new(["p@ss word"])

      expect(masker.string(%({"pw":"p@ss word"}))).to eq(%({"pw":"#{described_class::MASK}"}))
      expect(masker.string("pw=p%40ss%20word&x=1")).to eq("pw=#{described_class::MASK}&x=1")
      expect(masker.string("pw=p%40ss+word")).to eq("pw=#{described_class::MASK}")
    end

    it "masks secrets in the middle of an Authorization-like value" do
      expect(masker.string("Bearer secret-long.x")).to eq("Bearer #{described_class::MASK}.x")
    end

    it "does nothing without secrets", :aggregate_failures do
      expect(described_class.new([]).string("text")).to eq("text")
      expect(described_class.new([nil, "", "ab"]).string("ab")).to eq("ab")
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
