require "rails_helper"

RSpec.describe Monitoring::Notifications::Senders::Slack do
  let(:channel) { create(:notification_channel, :slack) }
  let(:monitor) { create(:uptime_monitor, project: channel.project, name: "<!channel> & co") }
  let(:incident) { create(:incident, uptime_monitor: monitor, cause: "connection_refused") }
  let(:message) { Monitoring::Notifications::Message.new(create(:notification_delivery, notification_channel: channel, incident:, event: "incident_opened")) }

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "posts the alert with a link, escaping what Slack would read as markup", :aggregate_failures do
    body = nil
    stub = stub_request(:post, channel.target).with { |request| (body = JSON.parse(request.body)) }.to_return(status: 200, body: "ok")

    expect(described_class.call(message)).to be_success
    expect(stub).to have_been_requested
    expect(body.keys).to eq(["text"])
    expect(body["text"]).to eq("🔴 &lt;!channel&gt; &amp; co is down: Connection refused\n<http://example.com/monitoring/monitors/#{monitor.id}|Open in Shango>")
  end

  it "gives up on a URL Slack no longer knows" do
    stub_request(:post, channel.target).to_return(status: 404, body: "no_service")

    expect(described_class.call(message)).to have_attributes(error: :unexpected_status, data: include(permanent: true))
  end
end
