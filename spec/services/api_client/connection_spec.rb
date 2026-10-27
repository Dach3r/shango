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

    it "times the DNS lookup" do
      timing = ApiClient::Timing.new
      allow(timing).to receive(:measure).with(:dns).and_call_original

      described_class.build(url: "https://a.test", timeout: 5, timing:)

      expect(timing).to have_received(:measure).with(:dns)
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

    it "checks the host without the brackets of an IPv6 literal", :aggregate_failures do
      allow(ApiClient::SsrfPolicy).to receive(:check!).and_return(nil)

      described_class.build(url: "http://[2606:4700::1111]:8080/x", timeout: 5)

      expect(ApiClient::SsrfPolicy).to have_received(:check!).with("2606:4700::1111")
    end

    it "checks the host and not the userinfo of the url", :aggregate_failures do
      allow(ApiClient::SsrfPolicy).to receive(:check!).and_return(nil)

      described_class.build(url: "http://example.com@evil.test/", timeout: 5)

      expect(ApiClient::SsrfPolicy).to have_received(:check!).with("evil.test")
    end

    it "blocks private literals when the policy is on", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_BLOCK_PRIVATE_NETWORKS" => "true"))

      ["http://127.0.0.1/", "http://[::1]/", "http://[::ffff:127.0.0.1]/", "http://169.254.169.254/latest", "http://2130706433/", "http://user:pw@10.0.0.1/"].each do |url|
        expect { described_class.build(url:, timeout: 5) }.to raise_error(ApiClient::SsrfPolicy::Blocked), url
      end
    end

    it "accepts an IPv6 literal that is public when the policy is on" do
      stub_const("ENV", ENV.to_h.merge("SHANGO_BLOCK_PRIVATE_NETWORKS" => "true"))

      expect(described_class.build(url: "http://[2606:4700::1111]/", timeout: 5)).to be_a(Faraday::Connection)
    end

    it "rejects other schemes", :aggregate_failures do
      %w[file:///etc/passwd gopher://a.test/ javascript:alert(1) data:text/plain,hi //a.test/x a.test].each do |url|
        expect { described_class.build(url:, timeout: 5) }.to raise_error(described_class::InvalidUrl), url
      end
    end

    it "rejects nil and blank urls", :aggregate_failures do
      expect { described_class.build(url: nil, timeout: 5) }.to raise_error(described_class::InvalidUrl)
      expect { described_class.build(url: "", timeout: 5) }.to raise_error(described_class::InvalidUrl)
    end

    it "rejects urls without a host" do
      expect { described_class.build(url: "http://", timeout: 5) }.to raise_error(described_class::InvalidUrl)
    end

    it "wraps malformed urls" do
      expect { described_class.build(url: "http://a b", timeout: 5) }.to raise_error(described_class::InvalidUrl)
    end
  end
end
