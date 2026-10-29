require "rails_helper"

RSpec.describe Monitoring::Notifications::Message do
  let(:project) { create(:project, name: "Acme") }
  let(:channel) { create(:notification_channel, project:, name: "Ops") }
  let(:monitor) { create(:uptime_monitor, project:, name: "API", settings: { "url" => "{{base}}/health" }) }
  let(:incident) { create(:incident, uptime_monitor: monitor, cause: "unexpected_status", detail: "503 Service Unavailable", started_at: Time.utc(2026, 10, 29, 12), resolved_at: nil) }

  def message(event, record = incident)
    described_class.new(create(:notification_delivery, notification_channel: channel, incident: record, event:))
  end

  it "says a monitor went down, with the URL as typed and a link", :aggregate_failures do
    opened = message("incident_opened")

    expect(opened.subject).to eq("[Down] API")
    expect(opened.text).to eq("🔴 API is down: Unexpected status (503 Service Unavailable)")
    expect(opened.target).to eq("{{base}}/health")
    expect(opened.kind_name).to eq("HTTP")
    expect(opened.duration).to be_nil
    expect(opened.url).to eq("http://example.com/monitoring/monitors/#{monitor.id}")
    expect(opened).not_to be_test
    expect(opened.payload[:incident]).to include(resolved_at: nil, duration_seconds: nil)
  end

  it "says how long it was down when it recovers, in the channel's language", :aggregate_failures do
    incident.update!(resolved_at: incident.started_at + 5.minutes, detail: nil)
    channel.update!(locale: "es")
    resolved = message("incident_resolved")

    expect(resolved.subject).to eq("[Arriba] API")
    expect(resolved.text).to eq("🟢 API volvió a estar arriba después de 5 minutos")
    expect(resolved.cause).to eq("Estado inesperado")
  end

  it "builds a JSON payload with the monitor and the incident", :aggregate_failures do
    incident.update!(resolved_at: incident.started_at + 90.seconds)
    payload = message("incident_resolved").payload

    expect(payload).to include(event: "incident_resolved", project: { id: project.id, name: "Acme" }, url: "http://example.com/monitoring/monitors/#{monitor.id}")
    expect(payload[:monitor]).to eq(id: monitor.id, name: "API", kind: "http", target: "{{base}}/health")
    expect(payload[:incident]).to include(cause: "unexpected_status", started_at: "2026-10-29T12:00:00Z", resolved_at: "2026-10-29T12:01:30Z", duration_seconds: 90)
  end

  it "names only the channel in a test", :aggregate_failures do
    test = described_class.new(create(:notification_delivery, notification_channel: channel))

    expect(test).to be_test
    expect(test.text).to eq("✅ Test alert for the channel Ops of Acme. Alerts reach this channel.")
    expect(test.subject).to eq("Test alert from Acme")
    expect(test).to have_attributes(cause: nil, target: nil, kind_name: nil, monitor: nil)
    expect(test.url).to eq("http://example.com/monitoring/channels")
    expect(test.payload).to include(monitor: nil, incident: nil)
  end

  it "describes the target of every kind", :aggregate_failures do
    targets = {
      create(:uptime_monitor, :tcp, project:) => "example.com:5432",
      create(:uptime_monitor, :ssl, project:) => "example.com:443",
      create(:uptime_monitor, :domain, project:) => "example.com",
      create(:uptime_monitor, :push, project:) => nil
    }
    targets.each do |record, target|
      expect(message("incident_opened", create(:incident, uptime_monitor: record)).target).to eq(target)
    end
  end

  it "names a saved request by its collection", :aggregate_failures do
    record = create(:uptime_monitor, :request, project:)
    record.api_request.collection.update!(name: "Shop")
    record.api_request.update!(name: "Health")

    expect(message("incident_opened", create(:incident, uptime_monitor: record, resolved_at: Time.current)).target).to eq("Shop / Health")
    record.update_columns(api_request_id: nil)
    expect(message("incident_opened", create(:incident, uptime_monitor: record.reload)).target).to be_nil
  end

  it "falls back to the cause key when it has no words" do
    incident.update!(cause: "something_new", detail: nil)

    expect(message("incident_opened").cause).to eq("something_new")
  end
end
