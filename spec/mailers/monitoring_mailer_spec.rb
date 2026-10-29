require "rails_helper"

RSpec.describe MonitoringMailer do
  let(:project) { create(:project, name: "Acme") }
  let(:channel) { create(:notification_channel, :email, project:, name: "Ops", target: "a@example.com, b@example.com") }
  let(:monitor) { create(:uptime_monitor, project:, name: "API") }

  def mail_for(delivery)
    described_class.with(delivery:).alert
  end

  it "tells the addresses a monitor went down", :aggregate_failures do
    incident = create(:incident, uptime_monitor: monitor, cause: "connection_refused")
    mail = mail_for(create(:notification_delivery, notification_channel: channel, incident:, event: "incident_opened"))
    body = mail.body.parts.map(&:decoded).join

    expect(mail.to).to eq(%w[a@example.com b@example.com])
    expect(mail.subject).to eq("[Down] API")
    expect(body).to include("API is down: Connection refused", "https://example.com/health", "http://example.com/monitoring/monitors/#{monitor.id}", "Ops", "Acme")
  end

  it "says when it recovered, in the channel's language", :aggregate_failures do
    channel.update!(locale: "de")
    incident = create(:incident, uptime_monitor: monitor, started_at: 1.hour.ago, resolved_at: Time.current)
    mail = mail_for(create(:notification_delivery, notification_channel: channel, incident:, event: "incident_resolved"))

    expect(mail.subject).to eq("[Wieder da] API")
    expect(mail.body.parts.map(&:decoded).join).to include("Wieder erreichbar um", "etwa eine Stunde")
  end

  it "sends a test without a monitor", :aggregate_failures do
    mail = mail_for(create(:notification_delivery, notification_channel: channel))
    body = mail.body.parts.map(&:decoded).join

    expect(mail.subject).to eq("Test alert from Acme")
    expect(body).to include("Test alert for the channel Ops", "http://example.com/monitoring/channels")
    expect(body).not_to include("Monitor:")
  end

  it "leaves out the target line when there is none" do
    incident = create(:incident, uptime_monitor: create(:uptime_monitor, :push, project:))
    body = mail_for(create(:notification_delivery, notification_channel: channel, incident:, event: "incident_opened")).body.parts.map(&:decoded).join

    expect(body).not_to include("Target:")
  end
end
