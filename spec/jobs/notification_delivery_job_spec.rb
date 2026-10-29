require "rails_helper"

RSpec.describe NotificationDeliveryJob do
  include ActiveJob::TestHelper

  let(:delivery) { create(:notification_delivery) }

  it "delivers and schedules its own retry", :aggregate_failures do
    allow(Monitoring::Notifications::Deliver).to receive(:call).and_return(Result.failure(error: :connection_timeout, retry_in: 30))

    expect { described_class.perform_now(delivery.id) }.to have_enqueued_job(described_class).with(delivery.id)
    expect(Monitoring::Notifications::Deliver).to have_received(:call).with(delivery:)
  end

  it "stops when sent, given up or gone", :aggregate_failures do
    allow(Monitoring::Notifications::Deliver).to receive(:call).and_return(Result.success(delivery))

    expect { described_class.perform_now(delivery.id) }.not_to have_enqueued_job
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to have_enqueued_job
  end
end
