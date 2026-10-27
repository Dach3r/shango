require "rails_helper"

RSpec.describe ApiRequest do
  subject(:api_request) { create(:api_request) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_inclusion_of(:http_method).in_array(described_class::METHODS) }
  it { is_expected.to validate_inclusion_of(:body_type).in_array(described_class::BODY_TYPES) }

  describe "project assignment" do
    it "takes the project from the collection" do
      expect(api_request.project_id).to eq(api_request.collection.project_id)
    end

    it "requires a collection", :aggregate_failures do
      request = build(:api_request, collection: nil)

      expect(request).not_to be_valid
      expect(request.project_id).to be_nil
    end
  end

  describe "folder validation" do
    it "rejects a folder from another collection" do
      expect(build(:api_request, collection: api_request.collection, folder: create(:folder))).not_to be_valid
    end

    it "accepts a folder from the same collection" do
      expect(build(:api_request, collection: api_request.collection, folder: create(:folder, collection: api_request.collection))).to be_valid
    end
  end

  describe "auth types" do
    it "allows inherit", :aggregate_failures do
      expect(api_request.auth_type).to eq("inherit")
      expect(api_request.allowed_auth_types).to include("inherit", "bearer")
    end
  end

  describe "row normalization" do
    it "drops blank rows and normalizes entries", :aggregate_failures do
      api_request.update!(headers: [{ key: "X", value: "1", enabled: "0" }, { key: "", value: "" }])

      expect(api_request.headers).to eq([{ "key" => "X", "value" => "1", "enabled" => false, "description" => "" }])
    end

    it "accepts hash-of-rows params" do
      api_request.update!(query_params: { "0" => { "key" => "a", "value" => "b" } })

      expect(api_request.query_params).to contain_exactly(hash_including("key" => "a", "value" => "b", "enabled" => true))
    end

    it "keeps extra keys for body_form" do
      api_request.update!(body_form: [{ key: "f", value: "", type: "file", attachment_id: "1", other: "x" }])

      expect(api_request.body_form.first).to eq("key" => "f", "value" => "", "enabled" => true, "description" => "", "type" => "file", "attachment_id" => "1")
    end
  end

  describe "settings" do
    it "fills defaults and clamps values", :aggregate_failures do
      api_request.update!(settings: { timeout: 9999, max_redirects: 99, follow_redirects: "false", verify_ssl: false })

      expect(api_request.settings).to eq("timeout" => 120, "follow_redirects" => false, "max_redirects" => 10, "verify_ssl" => false)
    end

    it "falls back to defaults for non-hash settings" do
      api_request.settings = "bad"
      api_request.valid?

      expect(api_request.settings).to eq(described_class::DEFAULT_SETTINGS)
    end

    it "keeps enabled flags true by default" do
      api_request.update!(settings: {})

      expect(api_request.settings).to include("follow_redirects" => true, "verify_ssl" => true)
    end
  end

  describe "#untouched_draft?" do
    let(:project) { create(:project) }
    let(:user) { create(:user) }
    let(:draft) { ApiClient::Requests::CreateDraft.call(project:, user:).record }

    it "is true for a draft that was never edited" do
      expect(draft).to be_untouched_draft
    end

    it "is false once the draft changes" do
      draft.update!(url: "https://example.com")

      expect(draft).not_to be_untouched_draft
    end

    it "is false for a draft with an attached file" do
      draft.binary_body.attach(io: StringIO.new("data"), filename: "a.bin")

      expect(draft).not_to be_untouched_draft
    end

    it "is false for a draft with body files" do
      draft.body_files.attach(io: StringIO.new("data"), filename: "a.txt")

      expect(draft).not_to be_untouched_draft
    end

    it "is false for a saved request" do
      expect(create(:api_request, project:)).not_to be_untouched_draft
    end
  end

  describe "#setting" do
    it "reads stored values and falls back to defaults", :aggregate_failures do
      api_request.update!(settings: { timeout: 10 })
      api_request.settings = api_request.settings.except("max_redirects")

      expect(api_request.setting(:timeout)).to eq(10)
      expect(api_request.setting("max_redirects")).to eq(5)
    end
  end

  describe "#siblings" do
    it "scopes to the same folder" do
      folder = create(:folder, collection: api_request.collection)
      inside = create(:api_request, collection: api_request.collection, folder:)

      expect(inside.siblings).to contain_exactly(inside)
    end
  end
end
