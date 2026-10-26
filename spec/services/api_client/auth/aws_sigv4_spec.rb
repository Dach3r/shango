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
end
