require "rails_helper"

RSpec.describe MonitorChannel do
  let(:project) { create(:project) }
  let(:monitor) { create(:uptime_monitor, project:) }

  it "links a monitor to a channel of its project once", :aggregate_failures do
    channel = create(:notification_channel, project:)
    create(:monitor_channel, uptime_monitor: monitor, notification_channel: channel)

    expect(build(:monitor_channel, uptime_monitor: monitor, notification_channel: channel)).to have_error(:notification_channel_id, :taken)
    expect(build(:monitor_channel, uptime_monitor: monitor, notification_channel: create(:notification_channel))).to have_error(:notification_channel, :invalid)
  end

  it "caps the channels of a monitor", :aggregate_failures do
    stub_const("MonitorChannel::PER_MONITOR", 1)
    create(:monitor_channel, uptime_monitor: monitor)

    expect(build(:monitor_channel, uptime_monitor: monitor)).to have_error(:base, :monitor_limit)
    expect(build(:monitor_channel, uptime_monitor: nil, notification_channel: nil)).not_to have_error(:base, :monitor_limit)
  end

  it "is deleted with its monitor" do
    create(:monitor_channel, uptime_monitor: monitor)

    expect { monitor.destroy! }.to change(described_class, :count).by(-1)
  end
end
