require "rails_helper"

RSpec.describe ApiClient::Drafts::Settings do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:draft) { ApiClient::Drafts::Create.call(project:, user:).record }
  let(:unsaved) { ApiClient::Drafts::Build.call(draft:) }

  it "keeps the settings in the draft, merging with earlier ones", :aggregate_failures do
    described_class.call(api_request: unsaved, user:, settings: { timeout: "9" })
    result = described_class.call(api_request: unsaved, user:, settings: { verify_ssl: "false" })

    expect(result).to be_success
    expect(draft.reload.data["settings"]).to eq("timeout" => "9", "verify_ssl" => "false")
  end

  it "fails when the draft is over the size limit" do
    stub_const("RequestDraft::MAX_BYTES", 5)

    expect(described_class.call(api_request: unsaved, user:, settings: { timeout: "9" })).to be_failure
  end

  it "cannot reach the draft of another user" do
    expect { described_class.call(api_request: unsaved, user: create(:user), settings: { timeout: "9" }) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "feeds the rebuilt request" do
    described_class.call(api_request: unsaved, user:, settings: { timeout: "9" })

    expect(ApiClient::Drafts::Build.call(draft: draft.reload)).to have_attributes(settings: include("timeout" => 9))
  end
end
