require "rails_helper"

RSpec.describe Incident do
  include ActiveSupport::Testing::TimeHelpers

  let(:window) { 2.hours.ago..Time.current }

  it "allows only one open incident per monitor", :aggregate_failures do
    incident = create(:incident)

    expect(incident).to be_open
    expect { create(:incident, uptime_monitor: incident.uptime_monitor) }.to raise_error(ActiveRecord::RecordNotUnique)

    incident.update!(resolved_at: Time.current, resolution: "recovered")

    expect(create(:incident, uptime_monitor: incident.uptime_monitor)).to be_open
    expect(described_class.open.count).to eq(1)
    expect(incident).to be_recovered
  end

  it "counts the seconds it lasted inside a window", :aggregate_failures do
    freeze_time do
      expect(build(:incident, started_at: 3.hours.ago, resolved_at: 1.hour.ago).seconds_within(window)).to eq(1.hour)
      expect(build(:incident, started_at: 30.minutes.ago).seconds_within(window)).to eq(30.minutes)
      expect(build(:incident, started_at: 5.hours.ago, resolved_at: 4.hours.ago).seconds_within(window)).to eq(0)
    end
  end

  it "lists the newest first" do
    old = create(:incident, started_at: 2.days.ago, resolved_at: 1.day.ago)
    recent = create(:incident, started_at: 1.hour.ago)

    expect(described_class.recent).to eq([recent, old])
  end

  it "keeps the resolution to known values" do
    expect { create(:incident).update_columns(resolution: "deleted") }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
