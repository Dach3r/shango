require "rails_helper"

RSpec.describe ApiClient::Drafts::Create do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  it "opens a blank draft owned by the user without writing a request", :aggregate_failures do
    result = nil

    expect { result = described_class.call(project:, user:) }.not_to change(ApiRequest, :count)
    expect(result).to be_success
    expect(result.record).to have_attributes(project:, user:, name: I18n.t("workbench.requests.draft_name"), api_request_id: nil)
    expect(result.record.data).to eq({})
  end

  it "opens the draft as a tab" do
    draft = described_class.call(project:, user:).record

    expect(RequestTab.where(user:, request_draft: draft)).to exist
  end
end
