require "rails_helper"

RSpec.describe Monitoring::Notifications::Senders::Webhook do
  include ActiveSupport::Testing::TimeHelpers

  let(:channel) { create(:notification_channel, target: "https://hooks.example.com/in") }
  let(:message) { Monitoring::Notifications::Message.new(create(:notification_delivery, notification_channel: channel)) }

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "signs the timestamp and the body with the channel's secret", :aggregate_failures do
    sent = nil
    stub_request(:post, "https://hooks.example.com/in").to_return { |request| (sent = request) && { status: 200 } }

    travel_to(Time.utc(2026, 10, 29, 12)) { expect(described_class.call(message)).to be_success }
    expected = OpenSSL::HMAC.hexdigest("SHA256", channel.signing_secret, "#{Time.utc(2026, 10, 29, 12).to_i}.#{sent.body}")
    expect(sent.headers).to include("X-Shango-Event" => "test", "X-Shango-Timestamp" => "1793275200", "X-Shango-Signature" => "sha256=#{expected}")
    expect(JSON.parse(sent.body)).to include("event" => "test", "text" => message.text)
  end

  it "matches a known signature" do
    expect(described_class.signature("secret", "1700000000", "{}")).to eq("sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "secret", "1700000000.{}")}")
  end
end
