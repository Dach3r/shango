require "rails_helper"

RSpec.describe ApiClient::Auth::AwsSigv4 do
  let(:config) { { "access_key" => "AKIA", "secret_key" => "secret", "region" => "us-east-1", "service" => "execute-api" } }
  let(:body) { "{}" }
  let(:request) { ApiClient::Auth::Request.new(http_method: "post", url: "https://api.example.com/x", headers: {}, body:) }

  it "signs the request", :aggregate_failures do
    described_class.new(config).apply(request)

    expect(request.headers["authorization"]).to include("AWS4-HMAC-SHA256", "Credential=AKIA/")
    expect(request.headers).to have_key("x-amz-date")
  end

  it "includes the session token when present", :aggregate_failures do
    described_class.new(config.merge("session_token" => "tok")).apply(request)

    expect(request.headers["x-amz-security-token"]).to eq("tok")
  end

  context "when the body is a stream" do
    let(:body) { nil }

    it "signs an empty payload" do
      described_class.new(config).apply(request)

      expect(request.headers["authorization"]).to be_present
    end
  end

  it "requires its fields" do
    expect { described_class.new({}).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError)
  end

  describe "odd inputs" do
      include ActiveSupport::Testing::TimeHelpers

      def build_request(method: "get", url: "https://a.test/x", body: nil)
        ApiClient::Auth::Request.new(http_method: method, url:, headers: {}, body:)
      end

      def signature(request)
        described_class.new(config).apply(request)
        request.headers["authorization"][/Signature=\h+/]
      end

      it "signs the same request the same way regardless of query order" do
        travel_to(Time.utc(2026, 1, 1)) do
          expect(signature(build_request(url: "https://a.test/x?b=2&a=1"))).to eq(signature(build_request(url: "https://a.test/x?a=1&b=2")))
        end
      end

      it "signs different bodies differently" do
        travel_to(Time.utc(2026, 1, 1)) do
          expect(signature(build_request(method: "post", body: "a"))).not_to eq(signature(build_request(method: "post", body: "b")))
        end
      end

      it "signs unicode and binary bodies" do
        ["héllo ✓", "\xFF\xFE".b].each do |payload|
          expect { described_class.new(config).apply(build_request(method: "post", body: payload)) }.not_to raise_error
        end
      end

      it "signs urls with a port" do
        request = build_request(url: "https://a.test:8443/x")
        described_class.new(config).apply(request)

        expect(request.headers["host"]).to eq("a.test:8443")
      end

      it "rejects blank required fields", :aggregate_failures do
        expect { described_class.new(config.merge("service" => " ")).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError, "Missing service")
        expect { described_class.new(config.merge("region" => "")).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError, "Missing region")
      end

      it "masks the secret key and the session token" do
        expect(described_class.new(config.merge("session_token" => "tok")).secrets).to contain_exactly("secret", "tok")
      end
    end
end
