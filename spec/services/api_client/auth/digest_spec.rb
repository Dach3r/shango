require "rails_helper"

RSpec.describe ApiClient::Auth::Digest do
  subject(:strategy) { described_class.new({ "username" => "ada", "password" => "pw" }) }

  let(:request) { ApiClient::Auth::Request.new(http_method: "get", url: "https://a.test/x", headers: {}, body: nil) }
  let(:challenge) { 'Digest realm="r", nonce="abc", qop="auth"' }
  let(:response) { instance_double(Faraday::Response, headers: { "www-authenticate" => challenge }) }

  describe "#apply" do
    it "sends nothing on the first attempt", :aggregate_failures do
      expect { strategy.apply(request) }.not_to raise_error
      expect(request.headers).to eq({})
    end

    it "requires a username" do
      expect { described_class.new({}).apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError)
    end
  end

  describe "#respond_to_challenge" do
    it "answers a digest challenge" do
      result = strategy.respond_to_challenge(response, request)

      expect(result["Authorization"]).to start_with("Digest username=\"ada\"")
    end

    context "when the challenge is not digest" do
      let(:challenge) { "Basic realm=\"r\"" }

      it "returns nil" do
        expect(strategy.respond_to_challenge(response, request)).to be_nil
      end
    end
  end

  describe "odd inputs" do
      it "keeps special characters of credentials" do
        header = described_class.new({ "username" => "a b@c:d", "password" => "p w/é" }).respond_to_challenge(response, request)["Authorization"]

        expect(header).to include('username="a b@c:d"')
      end

      it "signs the path with its query string in the original order" do
        request.url = "https://a.test/x?b=2&a=1"

        expect(strategy.respond_to_challenge(response, request)["Authorization"]).to include('uri="/x?b=2&a=1"')
      end

      it "ignores responses without a challenge header" do
        expect(strategy.respond_to_challenge(instance_double(Faraday::Response, headers: {}), request)).to be_nil
      end

      it "answers challenges without qop" do
        response = instance_double(Faraday::Response, headers: { "www-authenticate" => 'Digest realm="r", nonce="abc"' })

        expect(strategy.respond_to_challenge(response, request)["Authorization"]).not_to include("qop=")
      end

      it "answers with an empty password" do
        expect(described_class.new({ "username" => "ada" }).respond_to_challenge(response, request)["Authorization"]).to start_with("Digest")
      end
    end
end
