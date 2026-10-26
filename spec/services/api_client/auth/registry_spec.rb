require "rails_helper"

RSpec.describe ApiClient::Auth::Registry do
  describe ".keys" do
    it "lists every strategy key" do
      expect(described_class.keys).to eq(%w[none basic bearer api_key jwt_bearer digest aws_sigv4 oauth2])
    end
  end

  describe ".fetch" do
    it "returns the strategy class", :aggregate_failures do
      expect(described_class.fetch("basic")).to eq(ApiClient::Auth::Basic)
      expect(described_class.fetch(:bearer)).to eq(ApiClient::Auth::Bearer)
    end

    it "raises for unknown keys" do
      expect { described_class.fetch("nope") }.to raise_error(ApiClient::Auth::ConfigurationError, /Unknown authentication type: nope/)
    end
  end
end
