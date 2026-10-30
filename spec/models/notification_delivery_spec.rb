require "rails_helper"

RSpec.describe NotificationDelivery do
  let(:delivery) { create(:notification_delivery) }

  it "keeps the event and status as strings with a database check", :aggregate_failures do
    expect(described_class.events.values).to eq(%w[incident_opened incident_resolved test])
    expect(described_class.statuses.values).to eq(%w[pending sent failed])
    expect { delivery.update_columns(status: "lost") }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "is sent or given up only once, through its events", :aggregate_failures do
    at = 1.minute.ago.change(usec: 0)
    delivery.deliver!(at)

    expect(delivery).to have_attributes(status: "sent", sent_at: at)
    expect(delivery).to be_finished
    expect { delivery.give_up! }.to raise_error(AASM::InvalidTransition)
    expect { delivery.status = "pending" }.to raise_error(AASM::NoDirectAssignmentError)
  end

  it "stamps the sending time by default" do
    delivery.deliver!

    expect(delivery.sent_at).to be_within(1.second).of(Time.current)
  end

  it "fails from pending" do
    delivery.give_up!

    expect(delivery).to be_failed.and(be_finished)
  end

  it "is unique per channel, incident and event, but tests repeat", :aggregate_failures do
    opened = create(:notification_delivery, :opened)

    expect { described_class.create!(notification_channel: opened.notification_channel, incident: opened.incident, event: "incident_opened") }.to raise_error(ActiveRecord::RecordNotUnique)
    channel = delivery.notification_channel
    expect { 2.times { described_class.create!(notification_channel: channel, event: "test") } }.to change(described_class, :count).by(2)
  end

  it "orders the latest first" do
    older = create(:notification_delivery, created_at: 1.hour.ago)

    expect(described_class.recent).to eq([delivery, older])
  end
end
