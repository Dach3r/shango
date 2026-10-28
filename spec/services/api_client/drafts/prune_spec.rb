require "rails_helper"

RSpec.describe ApiClient::Drafts::Prune do
  it "deletes drafts untouched for the given days, with their tabs", :aggregate_failures do
    old = create(:request_draft, updated_at: 10.days.ago)
    create(:request_tab, user: old.user, api_request: nil, request_draft: old)
    recent = create(:request_draft, updated_at: 1.day.ago)

    described_class.call(days: 7)

    expect(RequestDraft.all).to contain_exactly(recent)
    expect(RequestTab.count).to eq(0)
  end

  it "deletes the latest responses untouched for the given days, those of drafts included", :aggregate_failures do
    draft = create(:request_draft, updated_at: 10.days.ago)
    create(:latest_execution, api_request: nil, request_draft: draft, project: draft.project, user: draft.user)
    old = create(:latest_execution, updated_at: 10.days.ago)
    recent = create(:latest_execution, updated_at: 1.day.ago)

    described_class.call(days: 7)

    expect(LatestExecution.all).to contain_exactly(recent)
    expect(LatestExecution.where(id: old.id)).not_to exist
  end
end
