require "rails_helper"

RSpec.describe ApiClient::Auth::EffectiveAuth do
  let(:collection) { create(:collection, auth_type: "bearer", auth_config: { "token" => "c" }) }
  let(:parent) { create(:folder, collection:, auth_type: "inherit") }
  let(:folder) { create(:folder, collection:, parent:, auth_type: "inherit") }
  let(:api_request) { create(:api_request, collection:, folder:, auth_type: "inherit") }

  it "inherits from the collection", :aggregate_failures do
    result = described_class.call(api_request:)

    expect(result.type).to eq("bearer")
    expect(result.config).to eq("token" => "c")
    expect(result.owner).to eq(collection)
  end

  it "uses the nearest folder that does not inherit" do
    parent.update!(auth_type: "basic", auth_config: { "username" => "u" })

    expect(described_class.call(api_request:).owner).to eq(parent)
  end

  it "uses the request itself" do
    api_request.update!(auth_type: "none")

    expect(described_class.call(api_request:).owner).to eq(api_request)
  end

  context "without a folder" do
    let(:api_request) { create(:api_request, collection:, auth_type: "inherit") }

    it "falls back to the collection" do
      expect(described_class.call(api_request:).owner).to eq(collection)
    end
  end
end
