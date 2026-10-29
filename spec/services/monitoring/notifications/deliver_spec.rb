require "rails_helper"

RSpec.describe Monitoring::Notifications::Deliver do
  let(:delivery) { create(:notification_delivery) }
  let(:sender) { Monitoring::Notifications::Senders::Webhook }

  def deliver
    described_class.call(delivery:)
  end

  it "marks a delivery sent and clears an earlier error", :aggregate_failures do
    delivery.update!(error: "connection_timeout", detail: "x", attempts: 1)
    allow(sender).to receive(:call).and_return(Result.success)

    expect(deliver).to be_success
    expect(delivery.reload).to have_attributes(status: "sent", attempts: 2, error: nil, detail: nil)
    expect(delivery.sent_at).to be_present
  end

  it "never sends a finished delivery again", :aggregate_failures do
    delivery.deliver!
    allow(sender).to receive(:call)

    expect(deliver).to be_success
    expect(sender).not_to have_received(:call)
  end

  it "keeps a failure pending with a growing wait while attempts remain", :aggregate_failures do
    allow(sender).to receive(:call).and_return(Result.failure(error: :connection_timeout))

    expect(deliver.data).to eq(retry_in: 10)
    expect(deliver.data).to eq(retry_in: 30)
    expect(delivery.reload).to have_attributes(status: "pending", attempts: 2, error: "connection_timeout")
  end

  it "waits as long as the receiver asks, up to an hour", :aggregate_failures do
    allow(sender).to receive(:call).and_return(Result.failure(error: :rate_limited, detail: "429", retry_after: 45), Result.failure(error: :rate_limited, retry_after: 99_999))

    expect(deliver.data[:retry_in]).to eq(45)
    expect(deliver.data[:retry_in]).to eq(3600)
  end

  it "gives up on a permanent failure or the last attempt", :aggregate_failures do
    allow(sender).to receive(:call).and_return(Result.failure(error: :unexpected_status, detail: "404" * 100, permanent: true))

    expect(deliver).to have_attributes(error: :unexpected_status, data: {})
    expect(delivery.reload).to have_attributes(status: "failed", error: "unexpected_status")
    expect(delivery.detail.length).to eq(255)

    other = create(:notification_delivery, attempts: NotificationDelivery::MAX_ATTEMPTS - 1)
    allow(sender).to receive(:call).and_return(Result.failure(error: :connection_timeout))
    described_class.call(delivery: other)
    expect(other.reload).to be_failed
  end

  it "sends with the sender of the channel's kind", :aggregate_failures do
    { email: Monitoring::Notifications::Senders::Email, slack: Monitoring::Notifications::Senders::Slack, discord: Monitoring::Notifications::Senders::Discord }.each do |kind, kind_sender|
      allow(kind_sender).to receive(:call).and_return(Result.success)
      expect(described_class.call(delivery: create(:notification_delivery, notification_channel: create(:notification_channel, kind)))).to be_success
      expect(kind_sender).to have_received(:call)
    end
  end
end
