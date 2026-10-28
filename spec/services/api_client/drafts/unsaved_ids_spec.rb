require "rails_helper"

RSpec.describe ApiClient::Drafts::UnsavedIds do
  let(:user) { create(:user) }
  let(:edited) { create(:api_request) }
  let(:untouched) { create(:api_request) }

  it "lists the saved requests with pending edits for the user", :aggregate_failures do
    create(:request_draft, :for_request, user:, api_request: edited, project: edited.project)
    create(:request_draft, :for_request, api_request: untouched, project: untouched.project)

    expect(described_class.call(requests: [edited, untouched], user:)).to eq([edited.id])
  end

  it "ignores requests that are not saved" do
    draft = ApiClient::Drafts::Build.call(draft: create(:request_draft, user:))

    expect(described_class.call(requests: [draft], user:)).to eq([])
  end
end
