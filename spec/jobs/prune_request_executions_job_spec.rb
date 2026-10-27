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

  it "is idempotent", :aggregate_failures do
    described_class.perform_now

    expect { described_class.perform_now }.not_to change(RequestExecution, :count)
    expect(RequestExecution.exists?(recent.id)).to be(true)
  end

  it "keeps everything for negative or non numeric retention", :aggregate_failures do
    ["-5", "abc", ""].each do |value|
      stub_const("ENV", ENV.to_h.merge("SHANGO_HISTORY_RETENTION_DAYS" => value))

      expect { described_class.perform_now }.not_to change(RequestExecution, :count)
    end
  end

  it "deletes every old execution", :aggregate_failures do
    create_list(:request_execution, 3, created_at: 200.days.ago)

    described_class.perform_now

    expect(RequestExecution.pluck(:id)).to eq([recent.id])
  end

  it "runs on the default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end
end
