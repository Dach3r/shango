require "rails_helper"

RSpec.describe Shango::EncryptionKeys do
  let(:derive) { ->(purpose) { "derived-#{purpose}" } }
  let(:pinned) do
    { "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => "p", "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => "d", "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => "s" }
  end

  describe ".resolve" do
    it "derives missing keys outside production" do
      expect(described_class.resolve(env: {}, production: false, derive:)).to eq(primary_key: "derived-primary_key", deterministic_key: "derived-deterministic_key", key_derivation_salt: "derived-key_derivation_salt")
    end

    it "uses the pinned keys" do
      expect(described_class.resolve(env: pinned, production: true, derive:)).to eq(primary_key: "p", deterministic_key: "d", key_derivation_salt: "s")
    end

    it "accepts several comma-separated keys for rotation, newest last" do
      env = pinned.merge("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => "old, new")

      expect(described_class.resolve(env:, production: true, derive:)[:primary_key]).to eq(%w[old new])
    end

    it "refuses to boot in production without explicit keys", :aggregate_failures do
      env = pinned.except("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")

      expect { described_class.resolve(env:, production: true, derive:) }.to raise_error(described_class::Missing, /ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY.*db:encryption:init.*derived_keys/m)
    end

    it "lets the operator keep derived keys explicitly" do
      env = { "SHANGO_ALLOW_DERIVED_ENCRYPTION_KEYS" => "true" }

      expect(described_class.resolve(env:, production: true, derive:)[:primary_key]).to eq("derived-primary_key")
    end
  end
end
