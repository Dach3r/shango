require "rails_helper"

RSpec.describe Monitoring::Notifications::Senders::Email do
  let(:channel) { create(:notification_channel, :email, target: "ops@example.com") }
  let(:message) { Monitoring::Notifications::Message.new(create(:notification_delivery, notification_channel: channel)) }

  it "needs SMTP" do
    allow(Shango::Mailing).to receive(:enabled?).and_return(false)

    expect(described_class.call(message)).to have_attributes(error: :mail_disabled, data: { permanent: true })
  end

  it "sends the alert to the addresses", :aggregate_failures do
    allow(Shango::Mailing).to receive(:enabled?).and_return(true)

    expect { expect(described_class.call(message)).to be_success }.to change(ActionMailer::Base.deliveries, :size).by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq(["ops@example.com"])
  end

  it "reports a mail server failure" do
    allow(Shango::Mailing).to receive(:enabled?).and_return(true)
    allow(MonitoringMailer).to receive(:with).and_raise(Net::SMTPServerBusy.new("busy"))

    expect(described_class.call(message)).to have_attributes(error: :mail_failed, data: { detail: "Net::SMTPServerBusy" })
  end
end
