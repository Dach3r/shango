require "rails_helper"

RSpec.describe ApiClient::Drafts::Duplicate do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:draft) { ApiClient::Drafts::Create.call(project:, user:).record }
  let(:api_request) { ApiClient::Drafts::Build.call(draft:) }

  before { draft.update!(name: "Login", http_method: "POST", payload: { name: "Login", url: "https://example.com", settings: { follow_redirects: false } }.to_json) }

  it "copies the draft with its edits as a new draft tab without writing a request", :aggregate_failures do
    result = nil

    expect { result = described_class.call(api_request:, user:) }.to change(RequestDraft, :count).by(1)
    expect(ApiRequest.count).to eq(0)
    copy = result.record
    expect(copy).to have_attributes(name: I18n.t("workbench.requests.copy_name", name: "Login"), http_method: "POST", api_request_id: nil, user:)
    expect(copy.data).to include("url" => "https://example.com", "name" => copy.name, "settings" => { "follow_redirects" => false })
    expect(RequestTab.where(user:, request_draft: copy)).to exist
  end

  it "leaves the original draft untouched" do
    described_class.call(api_request:, user:)

    expect(draft.reload.name).to eq("Login")
  end

  it "does not find the draft of another user" do
    expect { described_class.call(api_request:, user: create(:user)) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
