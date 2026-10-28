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

  describe "chains" do
      it "uses the nearest non-inheriting ancestor, not the farthest" do
        parent.update!(auth_type: "basic", auth_config: { "username" => "p" })
        folder.update!(auth_type: "bearer", auth_config: { "token" => "f" })

        expect(described_class.call(api_request:).owner).to eq(folder)
      end

      it "skips inheriting folders up to a grandparent" do
        grand = create(:folder, collection:, auth_type: "api_key", auth_config: { "key" => "k", "value" => "v" })
        parent.update!(parent: grand)

        expect(described_class.call(api_request:).owner).to eq(grand)
      end

      it "treats none as an explicit stop" do
        parent.update!(auth_type: "none")

        expect(described_class.call(api_request:)).to have_attributes(type: "none", owner: parent)
      end

      it "resolves to none for a draft without a collection" do
        draft = ApiClient::Drafts::Build.call(draft: create(:request_draft, project: collection.project))

        expect(described_class.call(api_request: draft)).to have_attributes(type: "none", owner: nil)
      end

      it "follows a deep folder nesting" do
        parent.update!(auth_type: "basic", auth_config: { "username" => "p" })
        leaf = Array.new(8).inject(parent) { |node, _| create(:folder, collection:, parent: node, auth_type: "inherit") }
        deep = create(:api_request, collection:, folder: leaf, auth_type: "inherit")

        expect(described_class.call(api_request: deep).owner).to eq(parent)
      end
    end
end
