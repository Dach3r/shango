require "rails_helper"

RSpec.describe CheckResult do
  it "keeps the status to known values", :aggregate_failures do
    expect(described_class.statuses.values).to eq(%w[up down unknown])
    expect { create(:check_result).update_columns(status: "slow") }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "requires the time of the check" do
    expect(build(:check_result, checked_at: nil)).not_to be_valid
  end

  it "lists the newest first" do
    monitor = create(:uptime_monitor)
    old = create(:check_result, uptime_monitor: monitor, checked_at: 2.minutes.ago)
    recent = create(:check_result, uptime_monitor: monitor, checked_at: 1.minute.ago)

    expect(described_class.recent).to eq([recent, old])
  end
end
