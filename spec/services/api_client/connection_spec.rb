require "rails_helper"

RSpec.describe ApiClient::Connection do
  describe ".build" do
    it "builds a Faraday connection with timeouts", :aggregate_failures do
      connection = described_class.build(url: "https://api.example.com", timeout: 30)

      expect(connection).to be_a(Faraday::Connection)
      expect(connection.options.timeout).to eq(30)
      expect(connection.options.open_timeout).to eq(10)
      expect(connection.ssl.verify).to be(true)
    end

    it "caps open timeout by timeout" do
      expect(described_class.build(url: "https://a.test", timeout: 3).options.open_timeout).to eq(3)
    end

    it "supports multipart and disabling ssl verification", :aggregate_failures do
      connection = described_class.build(url: "https://a.test", timeout: 5, verify_ssl: false, multipart: true)

      expect(connection.ssl.verify).to be(false)
      expect(connection.builder.handlers.map(&:klass)).to include(Faraday::Multipart::Middleware)
    end

    it "pins the resolved address" do
      allow(ApiClient::SsrfPolicy).to receive(:check!).and_return("93.184.216.34")
      stub_request(:get, "https://a.test/").to_return(status: 200)

      expect(described_class.build(url: "https://a.test", timeout: 5).get("https://a.test/").status).to eq(200)
    end

    it "does not pin an address when the policy is off" do
      stub_request(:get, "https://a.test/").to_return(status: 204)

      expect(described_class.build(url: "https://a.test", timeout: 5).get("https://a.test/").status).to eq(204)
    end

    it "rejects non http urls" do
      expect { described_class.build(url: "ftp://a.test", timeout: 5) }.to raise_error(described_class::InvalidUrl, /Only http/)
    end

    it "rejects urls without a host" do
      expect { described_class.build(url: "http://", timeout: 5) }.to raise_error(described_class::InvalidUrl)
    end

    it "wraps malformed urls" do
      expect { described_class.build(url: "http://a b", timeout: 5) }.to raise_error(described_class::InvalidUrl)
    end
  end
end
