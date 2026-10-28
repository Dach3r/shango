require "rails_helper"

RSpec.describe RequestDraft do
  subject(:draft) { create(:request_draft) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:api_request).optional }
  it { is_expected.to validate_presence_of(:name) }

  it "reads and writes its state as data", :aggregate_failures do
    draft.data = { "url" => "https://api.example.com" }

    expect(draft.data).to eq("url" => "https://api.example.com")
    expect(draft.payload).to eq('{"url":"https://api.example.com"}')
  end

  it "reads an unreadable payload as empty" do
    draft.payload = "not json"

    expect(draft.data).to eq({})
  end

  it "encrypts the payload at rest" do
    draft.update!(payload: { token: "s3cret" }.to_json)

    expect(described_class.connection.select_value("SELECT payload FROM request_drafts WHERE id = '#{draft.id}'")).not_to include("s3cret")
  end

  it "rejects an unknown method" do
    draft.http_method = "FETCH"

    expect(draft).not_to be_valid
  end

  it "rejects a payload over the size limit" do
    stub_const("#{described_class}::MAX_BYTES", 10)
    draft.payload = { url: "https://api.example.com/long" }.to_json

    expect(draft).not_to be_valid
  end

  describe "#new_request?" do
    it "is true without a saved request and false with one", :aggregate_failures do
      expect(draft).to be_new_request
      expect(create(:request_draft, :for_request)).not_to be_new_request
    end
  end

  describe "#untouched?" do
    it "is true until it is saved again", :aggregate_failures do
      expect(draft).to be_untouched

      draft.update!(payload: '{"url":"x"}', updated_at: 1.minute.from_now)

      expect(draft).not_to be_untouched
    end
  end

  describe ".stale" do
    it "keeps drafts untouched since the cutoff" do
      old = create(:request_draft, updated_at: 40.days.ago)
      create(:request_draft)

      expect(described_class.stale(30.days.ago)).to contain_exactly(old)
    end
  end

  it "keeps one draft per user and saved request", :aggregate_failures do
    first = create(:request_draft, :for_request)

    expect { create(:request_draft, project: first.project, user: first.user, api_request: first.api_request, name: "x") }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(create(:request_draft, project: first.project, user: create(:user), api_request: first.api_request, name: "x")).to be_persisted
  end

  it "goes away with its saved request, user and project", :aggregate_failures do
    create(:request_draft, :for_request)

    expect { ApiRequest.destroy_all }.to change(described_class, :count).by(-1)
    expect { create(:request_draft).user.destroy }.not_to change(described_class, :count)
  end
end
