require "rails_helper"

RSpec.describe ApiClient::Auth::Base do
  let(:strategy_class) do
    Class.new(described_class) do
      field :user, required: true
      field :pass, type: :password, secret: true

      def apply(request)
        require_config!("user", "pass")
        request
      end

      def dry?
        dry_run?
      end
    end
  end

  describe ".fields" do
    it "describes declared fields", :aggregate_failures do
      expect(strategy_class.field_names).to eq(%w[user pass])
      expect(strategy_class.secret_field_names).to eq(["pass"])
      expect(strategy_class.fields.first).to have_attributes(name: "user", type: :text, required: true, secret: false)
    end
  end

  describe ".managed_keys" do
    it "is empty by default" do
      expect(strategy_class.managed_keys).to eq([])
    end
  end

  describe ".key" do
    it "derives from the class name" do
      expect(ApiClient::Auth::ApiKey.key).to eq("api_key")
    end
  end

  describe "#initialize" do
    it "stringifies config keys and stores flags", :aggregate_failures do
      strategy = strategy_class.new({ user: "u" }, owner: :owner, dry_run: true)

      expect(strategy.config).to eq("user" => "u")
      expect(strategy.owner).to eq(:owner)
      expect(strategy.dry?).to be(true)
    end
  end

  describe "#apply" do
    it "must be implemented" do
      expect { described_class.new({}).apply(nil) }.to raise_error(NotImplementedError)
    end

    it "reports missing config", :aggregate_failures do
      expect { strategy_class.new({ "user" => "u" }).apply(nil) }.to raise_error(ApiClient::Auth::ConfigurationError, "Missing pass")
      expect(strategy_class.new({ "user" => "u", "pass" => "p" }).apply(:ok)).to eq(:ok)
    end
  end

  describe "#respond_to_challenge" do
    it "returns nil" do
      expect(described_class.new({}).respond_to_challenge(nil, nil)).to be_nil
    end
  end

  describe "#secrets" do
    it "returns non blank secret values" do
      expect(strategy_class.new({ "user" => "u", "pass" => "p" }).secrets).to eq(["p"])
    end

    it "skips blank secrets" do
      expect(strategy_class.new({ "pass" => "" }).secrets).to eq([])
    end
  end
end
