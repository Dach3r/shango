require "rails_helper"

RSpec.describe Monitoring::Notifications::Plan do
  include ActiveJob::TestHelper

  let(:monitor) { create(:uptime_monitor) }
  let(:incident) { create(:incident, uptime_monitor: monitor) }

  it "plans one pending delivery per enabled channel of the monitor", :aggregate_failures do
    on = create(:notification_channel, project: monitor.project)
    off = create(:notification_channel, project: monitor.project, enabled: false)
    create(:notification_channel, project: monitor.project)
    monitor.notification_channels = [on, off]
    deliveries = described_class.call(incident, "incident_opened")

    expect(deliveries.map(&:notification_channel)).to eq([on])
    expect(deliveries.first).to have_attributes(incident:, event: "incident_opened", status: "pending")
  end

  it "enqueues a job per delivery, and nothing for none", :aggregate_failures do
    delivery = create(:notification_delivery)

    expect { described_class.enqueue([delivery]) }.to have_enqueued_job(NotificationDeliveryJob).with(delivery.id)
    expect { described_class.enqueue([]) }.not_to have_enqueued_job
  end
end
