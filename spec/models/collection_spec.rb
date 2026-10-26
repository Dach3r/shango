require "rails_helper"

RSpec.describe Collection do
  subject(:collection) { create(:collection) }

  it { is_expected.to validate_presence_of(:name) }

  describe "auth type" do
    it "accepts registered strategies" do
      expect(build(:collection, auth_type: "bearer")).to be_valid
    end

    it "rejects inherit and unknown types", :aggregate_failures do
      expect(build(:collection, auth_type: "inherit")).not_to be_valid
      expect(build(:collection, auth_type: "nope")).not_to be_valid
    end
  end

  describe "#inherits_auth?" do
    it "is false for collections" do
      expect(collection).not_to be_inherits_auth
    end
  end

  describe "auth_config" do
    it "round-trips encrypted JSON" do
      collection.update!(auth_type: "bearer", auth_config: { "token" => "abc" })

      expect(collection.reload.auth_config).to eq("token" => "abc")
    end
  end

  describe "ordering" do
    it "appends and orders by position", :aggregate_failures do
      second = create(:collection, project: collection.project)

      expect(second.position).to eq(collection.position + 1)
      expect(collection.project.collections.ordered).to eq([collection, second])
    end
  end
end
