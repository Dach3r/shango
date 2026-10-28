require "rails_helper"

RSpec.describe ApiClient::Drafts::Build do
  let(:draft) { create(:request_draft, name: "Login", payload: { url: "https://api.example.com/login", http_method: "POST", headers: [{ key: "X", value: "1" }] }.to_json) }

  it "rebuilds the request in memory with the draft's id and owner", :aggregate_failures do
    request = described_class.call(draft:)

    expect(request).to be_new_record.and(be_draft)
    expect(request).to have_attributes(id: draft.id, project: draft.project, name: "Login", url: "https://api.example.com/login", http_method: "POST",
                                       draft_owner_id: draft.user_id, auth_type: "inherit", collection_id: nil)
    expect(request.headers).to eq([{ "key" => "X", "value" => "1", "enabled" => true, "description" => "" }])
  end

  it "never reaches the database", :aggregate_failures do
    request = described_class.call(draft:)

    expect(ApiRequest.where(id: request.id)).not_to exist
    expect(request.to_param).to eq(draft.id)
  end

  it "keeps the draft's timestamps so untouched ones can be told apart" do
    expect(described_class.call(draft:)).to be_untouched_draft
  end
end
