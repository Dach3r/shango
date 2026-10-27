require "rails_helper"

RSpec.describe ApiClient::Auth::Assign do
  let(:collection) { create(:collection) }

  describe ".call" do
    it "keeps only the fields of the chosen strategy", :aggregate_failures do
      result = described_class.call(record: collection, auth_type: "basic", auth_config: { "username" => "ada", "password" => "pw", "junk" => "x" })

      expect(result.auth_type).to eq("basic")
      expect(result.auth_config).to eq("username" => "ada", "password" => "pw")
    end

    it "accepts permitted-style params" do
      params = ActionController::Parameters.new(username: "ada")
      result = described_class.call(record: collection, auth_type: "basic", auth_config: params)

      expect(result.auth_config).to eq("username" => "ada")
    end

    it "keeps the current type when none is given" do
      collection.update!(auth_type: "bearer", auth_config: { "token" => "t" })
      result = described_class.call(record: collection, auth_type: "", auth_config: {})

      expect(result.auth_type).to eq("bearer")
    end

    it "returns an empty config for unknown types" do
      result = described_class.call(record: collection, auth_type: "inherit", auth_config: { "a" => "b" })

      expect(result.auth_config).to eq({})
    end

    context "with a stored secret" do
      before { collection.update!(auth_type: "basic", auth_config: { "username" => "ada", "password" => "pw" }) }

      it "keeps it when the input is blank" do
        result = described_class.call(record: collection, auth_type: "basic", auth_config: { "username" => "bob", "password" => "" })

        expect(result.auth_config).to eq("username" => "bob", "password" => "pw")
      end

      it "drops it when the type changes", :aggregate_failures do
        result = described_class.call(record: collection, auth_type: "digest", auth_config: { "username" => "bob" })

        expect(result.auth_config).to eq("username" => "bob")
      end
    end

    it "keeps managed OAuth tokens" do
      collection.update!(auth_type: "oauth2", auth_config: { "token_url" => "https://t", "access_token" => "at" })
      result = described_class.call(record: collection, auth_type: "oauth2", auth_config: { "token_url" => "https://t2" })

      expect(result.auth_config).to eq("token_url" => "https://t2", "access_token" => "at")
    end
  end

  describe "border cases" do
      it "never keeps stored secrets of another strategy", :aggregate_failures do
        collection.update!(auth_type: "bearer", auth_config: { "token" => "t" })
        result = described_class.call(record: collection, auth_type: "basic", auth_config: { "username" => "u" })

        expect(result.auth_config).to eq("username" => "u")
      end

      it "does not keep OAuth tokens when switching strategy", :aggregate_failures do
        collection.update!(auth_type: "oauth2", auth_config: { "token_url" => "https://t", "access_token" => "at", "refresh_token" => "rt" })
        result = described_class.call(record: collection, auth_type: "bearer", auth_config: { "token" => "t" })

        expect(result.auth_config).to eq("token" => "t")
      end

      it "does not let submitted params overwrite managed tokens" do
        collection.update!(auth_type: "oauth2", auth_config: { "token_url" => "https://t", "access_token" => "at" })
        result = described_class.call(record: collection, auth_type: "oauth2", auth_config: { "token_url" => "https://t", "access_token" => "forged" })

        expect(result.auth_config["access_token"]).to eq("at")
      end

      it "stores non-string values as strings" do
        expect(described_class.call(record: collection, auth_type: "basic", auth_config: { "username" => 123 }).auth_config).to eq("username" => "123")
      end

      it "is invalid for an unknown type" do
        expect(described_class.call(record: collection, auth_type: "kerberos", auth_config: {})).not_to be_valid
      end
    end
end
