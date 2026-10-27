require "rails_helper"

RSpec.describe PruneRequestExecutionsJob do
  let!(:old) { create(:request_execution, created_at: 100.days.ago) }
  let!(:recent) { create(:request_execution, created_at: 10.days.ago) }

  it "deletes executions past the default retention", :aggregate_failures do
    described_class.perform_now

    expect(RequestExecution.exists?(old.id)).to be(false)
    expect(RequestExecution.exists?(recent.id)).to be(true)
  end

  it "honors a custom retention", :aggregate_failures do
    stub_const("ENV", ENV.to_h.merge("SHANGO_HISTORY_RETENTION_DAYS" => "5"))
    described_class.perform_now

    expect(RequestExecution.where(id: [old.id, recent.id])).to be_empty
  end

  it "keeps everything when set to 0" do
    stub_const("ENV", ENV.to_h.merge("SHANGO_HISTORY_RETENTION_DAYS" => "0"))

    expect { described_class.perform_now }.not_to change(RequestExecution, :count)
  end
end
