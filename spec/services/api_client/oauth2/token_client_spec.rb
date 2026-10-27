require "rails_helper"

RSpec.describe ApiClient::Oauth2::TokenClient do
  include ActiveSupport::Testing::TimeHelpers

  subject(:client) { described_class.new(config:, owner:) }

  let(:token_url) { "https://auth.example.com/token" }
  let(:config) do
    { "grant_type" => "client_credentials", "token_url" => token_url, "client_id" => "id", "client_secret" => "secret", "scope" => "read" }
  end
  let(:owner) { create(:collection, auth_type: "oauth2", auth_config: config) }
  let(:token_body) { { access_token: "tok", refresh_token: "ref", token_type: "Bearer", expires_in: 60 } }
  let!(:stub) { stub_request(:post, token_url).to_return(status: 200, body: token_body.to_json) }

  describe "#fetch" do
    it "requests a token with basic client authentication and stores it", :aggregate_failures do
      freeze_time do
        client.fetch

        expect(stub.with(headers: { "Authorization" => "Basic #{Base64.strict_encode64("id:secret")}" }, body: "grant_type=client_credentials&scope=read")).to have_been_requested
        expect(owner.reload.auth_config).to include("access_token" => "tok", "refresh_token" => "ref", "token_type" => "Bearer", "expires_at" => 60.seconds.from_now.iso8601)
      end
    end

    it "does not clobber concurrent edits of the owner's settings", :aggregate_failures do
      Collection.find(owner.id).update!(auth_config: owner.auth_config.merge("scope" => "changed-elsewhere"))

      client.fetch

      expect(owner.reload.auth_config).to include("access_token" => "tok", "scope" => "changed-elsewhere")
    end

    it "sends credentials in the body when configured" do
      client = described_class.new(config: config.merge("client_authentication" => "body", "client_secret" => ""), owner:)
      client.fetch

      expect(a_request(:post, token_url).with(body: "grant_type=client_credentials&scope=read&client_id=id")).to have_been_made
    end

    it "sends username and password for the password grant" do
      client = described_class.new(config: config.merge("grant_type" => "password", "username" => "u", "password" => "p"), owner:)
      client.fetch

      expect(a_request(:post, token_url).with(body: /username=u&password=p/)).to have_been_made
    end

    it "keeps the previous refresh token and skips expiry when the server omits them", :aggregate_failures do
      stub_request(:post, token_url).to_return(status: 200, body: { access_token: "tok" }.to_json)
      described_class.new(config: config.merge("refresh_token" => "old"), owner:).fetch

      expect(owner.reload.auth_config).to include("access_token" => "tok", "refresh_token" => "old")
      expect(owner.auth_config).not_to include("expires_at")
    end

    it "fails without a token url" do
      client = described_class.new(config: config.merge("token_url" => ""), owner:)

      expect { client.fetch }.to raise_error(described_class::Failed, I18n.t("workbench.oauth2.missing_token_url"))
    end

    it "fails with the server error", :aggregate_failures do
      stub_request(:post, token_url).to_return(status: 400, body: { error: "invalid_client", error_description: "bad" }.to_json)

      expect { client.fetch }.to raise_error(described_class::Failed, "invalid_client: bad")
    end

    it "falls back to the HTTP status when the error body is empty" do
      stub_request(:post, token_url).to_return(status: 500, body: "{}")

      expect { client.fetch }.to raise_error(described_class::Failed, "HTTP 500")
    end

    it "fails on non-JSON responses" do
      stub_request(:post, token_url).to_return(status: 502, body: "<html>")

      expect { client.fetch }.to raise_error(described_class::Failed, "HTTP 502: #{I18n.t("workbench.oauth2.invalid_response")}")
    end

    it "wraps connection errors" do
      stub_request(:post, token_url).to_timeout

      expect { client.fetch }.to raise_error(described_class::Failed)
    end

    it "wraps invalid urls" do
      client = described_class.new(config: config.merge("token_url" => "ftp://x.test"), owner:)

      expect { client.fetch }.to raise_error(described_class::Failed, /http and https/)
    end
  end

  describe "#refresh_or_fetch" do
    it "fetches when there is no refresh token" do
      client.refresh_or_fetch

      expect(a_request(:post, token_url).with(body: /grant_type=client_credentials/)).to have_been_made
    end

    it "refreshes when a refresh token exists" do
      described_class.new(config: config.merge("refresh_token" => "ref"), owner:).refresh_or_fetch

      expect(a_request(:post, token_url).with(body: /grant_type=refresh_token&refresh_token=ref/)).to have_been_made
    end
  end

  describe "#refresh" do
    let(:refreshing) { described_class.new(config: config.merge("refresh_token" => "ref"), owner:) }

    it "falls back to fetching for machine grants" do
      stub_request(:post, token_url).with(body: /refresh_token/).to_return(status: 400, body: { error: "invalid_grant" }.to_json)

      refreshing.refresh

      expect(a_request(:post, token_url).with(body: /grant_type=client_credentials/)).to have_been_made
    end

    it "re-raises for interactive grants" do
      stub_request(:post, token_url).to_return(status: 400, body: { error: "invalid_grant" }.to_json)
      refreshing = described_class.new(config: config.merge("grant_type" => "authorization_code", "refresh_token" => "ref"), owner:)

      expect { refreshing.refresh }.to raise_error(described_class::Failed, "invalid_grant")
    end
  end

  describe "#exchange_code" do
    it "exchanges the authorization code" do
      client.exchange_code(code: "c", verifier: "v", redirect_uri: "https://app.test/cb")

      expect(a_request(:post, token_url).with(body: /grant_type=authorization_code&code=c&redirect_uri=.+&code_verifier=v/)).to have_been_made
    end
  end
end
