require "rails_helper"

RSpec.describe Monitoring::Channels::SendTest do
  include ActiveJob::TestHelper

  it "creates a test delivery and sends it in the background", :aggregate_failures do
    channel = create(:notification_channel)
    result = nil

    expect { result = described_class.call(channel:) }.to have_enqueued_job(NotificationDeliveryJob)
    expect(result.record).to have_attributes(event: "test", status: "pending", notification_channel: channel)
  end
end
