require "rails_helper"

RSpec.describe PruneRequestDraftsJob do
  let!(:old) { create(:request_draft, updated_at: 40.days.ago) }
  let!(:recent) { create(:request_draft, updated_at: 2.days.ago) }

  it "deletes drafts untouched for more than 30 days by default" do
    described_class.perform_now

    expect(RequestDraft.all).to contain_exactly(recent)
  end

  it "takes the retention from SHANGO_DRAFT_RETENTION_DAYS" do
    stub_const("ENV", ENV.to_h.merge("SHANGO_DRAFT_RETENTION_DAYS" => "1"))
    described_class.perform_now

    expect(RequestDraft.count).to eq(0)
  end

  it "keeps everything when the retention is 0" do
    stub_const("ENV", ENV.to_h.merge("SHANGO_DRAFT_RETENTION_DAYS" => "0"))

    expect { described_class.perform_now }.not_to change(RequestDraft, :count)
  end

  it "is scheduled in production" do
    expect(YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "prune_request_drafts", "class")).to eq("PruneRequestDraftsJob")
  end
end
