require "rails_helper"

RSpec.describe ApiClient::Auth::Oauth2 do
  subject(:strategy) { described_class.new(config, owner:, dry_run:) }

  let(:request) { ApiClient::Auth::Request.new(http_method: "GET", url: "https://a.test/x", headers: {}, body: nil) }
  let(:owner) { build(:collection) }
  let(:dry_run) { false }
  let(:config) { { "grant_type" => "client_credentials", "access_token" => "tok", "token_type" => "Bearer" } }
  let(:token_client) { instance_double(ApiClient::Oauth2::TokenClient) }

  before { allow(ApiClient::Oauth2::TokenClient).to receive(:new).and_return(token_client) }

  describe ".managed_keys" do
    it "lists token keys" do
      expect(described_class.managed_keys).to contain_exactly("access_token", "refresh_token", "expires_at", "token_type")
    end
  end

  describe "#apply" do
    it "sets the authorization header from the token type" do
      config["token_type"] = "MAC"
      strategy.apply(request)

      expect(request.headers["Authorization"]).to eq("MAC tok")
    end

    it "prefers the configured prefix" do
      config["prefix"] = "Token"
      strategy.apply(request)

      expect(request.headers["Authorization"]).to eq("Token tok")
    end

    it "falls back to Bearer" do
      config.delete("token_type")
      strategy.apply(request)

      expect(request.headers["Authorization"]).to eq("Bearer tok")
    end

    it "adds the token to the query", :aggregate_failures do
      config["add_to"] = "query"
      strategy.apply(request)

      expect(request.url).to eq("https://a.test/x?access_token=tok")
    end

    it "uses a custom query param" do
      config.merge!("add_to" => "query", "query_param" => "t")
      strategy.apply(request)

      expect(request.url).to eq("https://a.test/x?t=tok")
    end

    context "when there is no token and the grant cannot fetch one" do
      let(:config) { { "grant_type" => "authorization_code" } }

      it "raises" do
        expect { strategy.apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError, /No access token/)
      end
    end

    context "when there is no token and the grant is client_credentials" do
      let(:config) { { "grant_type" => "client_credentials" } }

      before { allow(token_client).to receive(:refresh_or_fetch).and_return("access_token" => "new") }

      it "fetches one", :aggregate_failures do
        strategy.apply(request)

        expect(request.headers["Authorization"]).to eq("Bearer new")
        expect(strategy.config["access_token"]).to eq("new")
      end
    end

    context "when the token expired" do
      let(:config) { { "grant_type" => "authorization_code", "access_token" => "old", "refresh_token" => "r", "expires_at" => 1.minute.ago.iso8601 } }

      before { allow(token_client).to receive(:refresh_or_fetch).and_return("access_token" => "fresh") }

      it "refreshes it" do
        strategy.apply(request)

        expect(request.headers["Authorization"]).to eq("Bearer fresh")
      end
    end

    context "when the token is still valid" do
      let(:config) { { "access_token" => "ok", "refresh_token" => "r", "expires_at" => 1.hour.from_now.iso8601 } }

      it "does not refresh", :aggregate_failures do
        strategy.apply(request)

        expect(ApiClient::Oauth2::TokenClient).not_to have_received(:new)
        expect(request.headers["Authorization"]).to eq("Bearer ok")
      end
    end

    context "when the refresh fails" do
      let(:config) { { "grant_type" => "password", "refresh_token" => "r" } }

      before { allow(token_client).to receive(:refresh_or_fetch).and_raise(ApiClient::Oauth2::TokenClient::Failed, "denied") }

      it "raises a configuration error" do
        expect { strategy.apply(request) }.to raise_error(ApiClient::Auth::ConfigurationError, "denied")
      end
    end

    context "when dry run" do
      let(:dry_run) { true }
      let(:config) { { "grant_type" => "client_credentials", "access_token" => "old", "expires_at" => 1.minute.ago.iso8601 } }

      it "never refreshes" do
        strategy.apply(request)

        expect(ApiClient::Oauth2::TokenClient).not_to have_received(:new)
      end
    end

    context "when there is no owner" do
      let(:owner) { nil }

      it "never refreshes" do
        strategy.apply(request)

        expect(ApiClient::Oauth2::TokenClient).not_to have_received(:new)
      end
    end
  end

  describe "#secrets" do
    let(:config) { { "client_secret" => "cs", "access_token" => "at", "refresh_token" => "" } }

    it "includes field and managed secrets" do
      expect(strategy.secrets).to contain_exactly("cs", "at")
    end
  end
end
