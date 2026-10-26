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
end
