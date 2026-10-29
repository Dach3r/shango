require "rails_helper"

RSpec.describe Monitoring::Channels::Destroy do
  it "deletes the channel and records it by name", :aggregate_failures do
    channel = create(:notification_channel, name: "Ops")
    described_class.call(channel:)

    expect(NotificationChannel.exists?(channel.id)).to be(false)
    expect(AuditEvent.sole).to have_attributes(kind: "channel_deleted", actor: nil, metadata: include("name" => "Ops"))
  end
end
