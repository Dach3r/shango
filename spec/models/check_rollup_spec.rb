require "rails_helper"

RSpec.describe CheckRollup do
  it "averages the response time of its checks", :aggregate_failures do
    expect(build(:check_rollup).average_ms).to eq(120)
    expect(build(:check_rollup, checks: 0, response_ms_sum: 0).average_ms).to be_nil
  end

  it "keeps one row per monitor and hour", :aggregate_failures do
    rollup = create(:check_rollup)

    expect { create(:check_rollup, uptime_monitor: rollup.uptime_monitor, hour: rollup.hour) }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(build(:check_rollup, hour: nil)).not_to be_valid
  end
end
