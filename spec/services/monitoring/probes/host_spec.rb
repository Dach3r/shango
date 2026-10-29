require "rails_helper"

RSpec.describe Monitoring::Probes::Host do
  let(:project) { create(:project) }
  let(:monitor) { build(:uptime_monitor, :tcp, project:, settings: { "host" => "https://Example.com/path", "port" => 22 }) }

  def stopped(record = monitor)
    described_class.call(record)
  rescue described_class::Stop => stop
    stop.outcome
  end

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "cleans up the host and returns it with the checked address" do
    expect(described_class.call(monitor)).to eq(["example.com", "203.0.113.9"])
  end

  it "resolves variables from the environment and refuses secret ones", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "host", value: "db.example.com")
    create(:variable, environment:, key: "token", value: "x", secret: true)
    monitor.assign_attributes(environment:, settings: { "host" => "{{host}}", "port" => 22 })

    expect(described_class.call(monitor).first).to eq("db.example.com")
    monitor.settings = { "host" => "{{token}}", "port" => 22 }
    expect(stopped).to have_attributes(error: "secret_variable", detail: "token")
    monitor.settings = { "host" => "{{missing}}", "port" => 22 }
    expect(stopped).to have_attributes(error: "unresolved_variable", detail: "missing")
  end

  it "stops when its environment is gone or the host is not valid", :aggregate_failures do
    expect(stopped(build(:uptime_monitor, :tcp, environment_required: true))).to have_attributes(status: "down", error: "environment_missing")
    expect(stopped(build(:uptime_monitor, :tcp, settings: { "host" => "bad host!", "port" => 1 }))).to have_attributes(error: "invalid_host")
    expect(stopped(build(:uptime_monitor, :tcp, settings: { "host" => "https://", "port" => 1 }))).to have_attributes(error: "invalid_host")
  end

  it "stops at the guard and at metadata addresses", :aggregate_failures do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked, detail: "private"))
    expect(stopped).to have_attributes(error: "blocked", detail: "private")
    allow(Network::Destination).to receive(:call).and_return(Result.success("169.254.169.254"))
    expect(stopped).to have_attributes(error: "blocked", detail: "example.com resolves to a cloud metadata address (169.254.169.254)")
  end
end
