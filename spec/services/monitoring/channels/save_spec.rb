require "rails_helper"

RSpec.describe Monitoring::Channels::Save do
  let(:channel) { create(:notification_channel, target: "https://hooks.example.com/one") }

  it "keeps the current URL when the form leaves it blank", :aggregate_failures do
    expect(described_class.call(channel:, attributes: { name: "Renamed", target: "" })).to be_success
    expect(channel.reload).to have_attributes(name: "Renamed", target: "https://hooks.example.com/one")
  end

  it "replaces the URL when one is given" do
    described_class.call(channel:, attributes: { "target" => "https://hooks.example.com/two" })

    expect(channel.reload.target).to eq("https://hooks.example.com/two")
  end

  it "requires the URL of a new channel and the addresses of an email channel", :aggregate_failures do
    expect(described_class.call(channel: build(:notification_channel), attributes: { target: "" })).to have_attributes(error: :invalid)
    expect(described_class.call(channel: create(:notification_channel, :email), attributes: { target: "" })).to have_attributes(error: :invalid)
  end
end
