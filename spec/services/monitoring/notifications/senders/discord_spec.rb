require "rails_helper"

RSpec.describe Monitoring::Notifications::Senders::Discord do
  let(:channel) { create(:notification_channel, :discord) }
  let(:message) { Monitoring::Notifications::Message.new(create(:notification_delivery, notification_channel: channel)) }

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "posts the alert with a link and no mentions", :aggregate_failures do
    body = nil
    stub_request(:post, channel.target).with { |request| (body = JSON.parse(request.body)) }.to_return(status: 204)

    expect(described_class.call(message)).to be_success
    expect(body).to eq("content" => "#{message.text}\nhttp://example.com/monitoring/channels", "allowed_mentions" => { "parse" => [] })
  end

  it "keeps the content within Discord's limit" do
    body = nil
    allow(message).to receive(:text).and_return("x" * 2500)
    stub_request(:post, channel.target).with { |request| (body = JSON.parse(request.body)) }.to_return(status: 204)
    described_class.call(message)

    expect(body["content"].length).to eq(2000)
  end

  it "passes on how long Discord asks to wait" do
    stub_request(:post, channel.target).to_return(status: 429, headers: { "Retry-After" => "3" })

    expect(described_class.call(message)).to have_attributes(error: :rate_limited, data: include(retry_after: 3))
  end
end
