require "rails_helper"

RSpec.describe Variable do
  subject(:variable) { create(:variable) }

  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_uniqueness_of(:key).scoped_to(:environment_id) }

  describe "key format" do
    it "accepts identifiers" do
      expect(build(:variable, key: "base.url-1_x")).to be_valid
    end

    it "rejects invalid keys" do
      expect(build(:variable, key: "1bad key")).not_to be_valid
    end
  end

  it "encrypts the value" do
    expect(variable.value_before_type_cast).not_to eq("value")
  end

  describe "#value=" do
    let(:secret_variable) { create(:variable, :secret, value: "keep") }

    it "keeps a persisted secret when the new value is blank" do
      secret_variable.update!(value: "")

      expect(secret_variable.reload.value).to eq("keep")
    end

    it "replaces a persisted secret with a present value" do
      secret_variable.update!(value: "new")

      expect(secret_variable.reload.value).to eq("new")
    end

    it "assigns a blank value to a persisted non-secret" do
      variable.update!(value: "")

      expect(variable.reload.value).to eq("")
    end

    it "assigns on a new secret" do
      expect(build(:variable, :secret, value: "").value).to eq("")
    end
  end

  describe "database constraints" do
    it "rejects a duplicate key in an environment even without validations" do
      existing = create(:variable, key: "HOST")

      expect { build(:variable, environment: existing.environment, key: "HOST").save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same key in different environments" do
      create(:variable, key: "HOST")

      expect(build(:variable, key: "HOST")).to be_valid
    end

    it "treats keys as case sensitive" do
      existing = create(:variable, key: "HOST")

      expect(build(:variable, environment: existing.environment, key: "host")).to be_valid
    end
  end

  describe "#masked_value" do
    it "masks a present secret", :aggregate_failures do
      expect(build(:variable, :secret, value: "s3cret").masked_value).to eq(ApiClient::Masker::MASK)
      expect(build(:variable, :secret, value: "").masked_value).to eq("")
    end

    it "returns plain values and an empty string for nil", :aggregate_failures do
      expect(build(:variable, value: "plain").masked_value).to eq("plain")
      expect(build(:variable, value: nil).masked_value).to eq("")
    end
  end

  describe "key format" do
    it "rejects keys starting with a digit, dash or dot and keys with whitespace", :aggregate_failures do
      ["9a", "-a", ".a", "a b", "a\nb", "ñ"].each { |key| expect(build(:variable, key:)).not_to be_valid, key }
    end

    it "rejects a trailing newline" do
      expect(build(:variable, key: "abc\n")).not_to be_valid
    end
  end

  it "keeps very long unicode values" do
    value = "ñandú ✓ " * 5_000

    expect(create(:variable, value:).reload.value).to eq(value)
  end
end
