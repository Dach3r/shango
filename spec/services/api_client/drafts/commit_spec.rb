require "rails_helper"

RSpec.describe ApiClient::Drafts::Commit do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:collection) { create(:collection, project:) }
  let(:draft) { ApiClient::Drafts::Create.call(project:, user:).record }
  let(:unsaved) { ApiClient::Drafts::Build.call(draft:) }

  before do
    ApiClient::Drafts::Save.call(api_request: unsaved, user:, attributes: { name: "Login", url: "https://api.example.com/login", http_method: "POST" })
    ApiClient::Drafts::Settings.call(api_request: unsaved, user:, settings: { timeout: "9" })
  end

  it "saves the draft as a request of the collection", :aggregate_failures do
    result = described_class.call(api_request: unsaved, user:, collection:)

    expect(result).to be_success
    expect(result.record).to be_persisted.and have_attributes(collection:, folder: nil, project:, name: "Login", url: "https://api.example.com/login", http_method: "POST")
    expect(result.record.setting(:timeout)).to eq(9)
  end

  it "saves it under the given name" do
    expect(described_class.call(api_request: unsaved, user:, collection:, name: "Sign in").record.name).to eq("Sign in")
  end

  it "does not save it under a blank name" do
    expect(described_class.call(api_request: unsaved, user:, collection:, name: "")).to be_failure
  end

  it "saves it into a folder" do
    folder = create(:folder, collection:)

    expect(described_class.call(api_request: unsaved, user:, collection:, folder:).record.folder).to eq(folder)
  end

  it "puts it last among the siblings of its destination", :aggregate_failures do
    existing = create(:api_request, collection:)

    expect(described_class.call(api_request: unsaved, user:, collection:).record.position).to be > existing.position
    expect(described_class.call(api_request: ApiClient::Drafts::Build.call(draft: ApiClient::Drafts::Create.call(project:, user:).record), user:, collection:, folder: create(:folder, collection:)).record.position).to eq(1)
  end

  it "moves the latest response of the draft to the request", :aggregate_failures do
    create(:latest_execution, api_request: nil, request_draft: draft, project:, user:)

    saved = described_class.call(api_request: unsaved, user:, collection:).record

    expect(LatestExecution.pluck(:api_request_id, :request_draft_id)).to eq([[saved.id, nil]])
  end

  it "consumes the draft and moves its tab to the request", :aggregate_failures do
    saved = described_class.call(api_request: unsaved, user:, collection:).record

    expect(RequestDraft.where(id: draft.id)).not_to exist
    expect(RequestTab.where(user:).pluck(:api_request_id, :request_draft_id)).to eq([[saved.id, nil]])
  end

  it "fails and keeps the draft when the request is invalid", :aggregate_failures do
    result = described_class.call(api_request: unsaved, user:, collection:, folder: create(:folder))

    expect(result).to be_failure
    expect(RequestDraft.where(id: draft.id)).to exist
    expect(RequestTab.where(request_draft: draft)).to exist
  end

  it "cannot commit the draft of another user" do
    expect { described_class.call(api_request: unsaved, user: create(:user), collection:) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
