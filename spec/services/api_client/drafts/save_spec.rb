require "rails_helper"

RSpec.describe ApiClient::Drafts::Save do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:api_request) { create(:api_request, project:, collection: create(:collection, project:)) }
  let(:new_draft) { ApiClient::Drafts::Create.call(project:, user:).record }
  let(:unsaved) { ApiClient::Drafts::Build.call(draft: new_draft) }

  describe "for a saved request" do
    it "keeps the pending edits per user and request", :aggregate_failures do
      result = described_class.call(api_request:, user:, attributes: { name: "Edited", url: "https://edited.test", headers: [{ key: "X", value: "1" }] })

      expect(result).to be_success
      expect(result.record).to have_attributes(api_request:, project:, user:, name: "Edited")
      expect(result.record.data).to include("url" => "https://edited.test", "headers" => [{ "key" => "X", "value" => "1" }])
      expect(api_request.reload.url).not_to eq("https://edited.test")
      expect(create(:user).request_drafts.find_by(api_request:)).to be_nil
    end

    it "replaces its previous state in the same row", :aggregate_failures do
      described_class.call(api_request:, user:, attributes: { url: "https://one.test" })

      expect { described_class.call(api_request:, user:, attributes: { url: "https://two.test" }) }.not_to change(RequestDraft, :count)
      expect(user.request_drafts.find_by!(api_request:).data["url"]).to eq("https://two.test")
    end

    it "keeps the request's name when the edits carry none" do
      described_class.call(api_request:, user:, attributes: { url: "https://one.test" })

      expect(user.request_drafts.find_by!(api_request:).name).to eq(api_request.name)
    end
  end

  describe "for a new draft" do
    it "updates the draft, never writing a request", :aggregate_failures do
      result = nil

      expect { result = described_class.call(api_request: unsaved, user:, attributes: { name: "Login", http_method: "post", url: "https://api.example.com" }) }.not_to change(ApiRequest, :count)
      expect(result.record).to have_attributes(id: new_draft.id, name: "Login", http_method: "POST")
      expect(result.record.data).to include("url" => "https://api.example.com")
    end

    it "keeps the current method when the edits carry an unknown one" do
      described_class.call(api_request: unsaved, user:, attributes: { http_method: "FETCH" })

      expect(new_draft.reload.http_method).to eq("GET")
    end

    it "cannot reach the draft of another user" do
      expect { described_class.call(api_request: unsaved, user: create(:user), attributes: { url: "x" }) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  it "keeps credentials, encrypted at rest", :aggregate_failures do
    draft = described_class.call(api_request:, user:, attributes: { auth_type: "basic", auth_config: { username: "ana", password: "s3cret" } }).record

    expect(draft.data["auth_config"]).to eq("username" => "ana", "password" => "s3cret")
    expect(RequestDraft.connection.select_value("SELECT payload FROM request_drafts WHERE id = '#{draft.id}'")).not_to include("s3cret")
  end

  it "keeps the settings saved separately" do
    ApiClient::Drafts::Settings.call(api_request: unsaved, user:, settings: { timeout: "9" })
    described_class.call(api_request: unsaved, user:, attributes: { url: "https://api.example.com" })

    expect(new_draft.reload.data["settings"]).to eq("timeout" => "9")
  end

  it "fails when the state is over the size limit", :aggregate_failures do
    stub_const("RequestDraft::MAX_BYTES", 10)
    result = described_class.call(api_request:, user:, attributes: { url: "https://edited.test" })

    expect(result).to be_failure
    expect(user.request_drafts.find_by(api_request:)).to be_nil
  end
end
