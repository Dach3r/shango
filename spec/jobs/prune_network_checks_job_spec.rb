require "rails_helper"

RSpec.describe PruneNetworkChecksJob do
  let!(:old) { create(:network_check, created_at: 100.days.ago) }
  let!(:recent) { create(:network_check, created_at: 10.days.ago) }

  it "deletes runs past the default retention", :aggregate_failures do
    described_class.perform_now

    expect(NetworkCheck.exists?(old.id)).to be(false)
    expect(NetworkCheck.exists?(recent.id)).to be(true)
  end

  it "honors a custom retention" do
    stub_const("ENV", ENV.to_h.merge("SHANGO_NETWORK_HISTORY_RETENTION_DAYS" => "5"))
    described_class.perform_now

    expect(NetworkCheck.where(id: [old.id, recent.id])).to be_empty
  end

  it "keeps everything when set to 0" do
    stub_const("ENV", ENV.to_h.merge("SHANGO_NETWORK_HISTORY_RETENTION_DAYS" => "0"))

    expect { described_class.perform_now }.not_to change(NetworkCheck, :count)
  end
end
