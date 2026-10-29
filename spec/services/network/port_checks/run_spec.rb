require "rails_helper"

RSpec.describe Network::PortChecks::Run do
  def attempt(status, ms = 5)
    Network::Tcp::Probe::Attempt.new(status:, ms:)
  end

  def stub_destination(address = "203.0.113.9")
    allow(Network::Destination).to receive(:call).and_return(Result.success(address))
  end

  def stub_probes(by_port)
    allow(Network::Tcp::Probe).to receive(:call) { |port:, **| by_port.fetch(port) }
  end

  def run(**options)
    described_class.call(host: "Example.com", ports: "22, 80, 443", **options)
  end

  before { stub_destination }

  it "probes every port on the approved address", :aggregate_failures do
    stub_probes(22 => attempt(:open), 80 => attempt(:closed), 443 => attempt(:filtered))
    result = run

    expect(result).to be_success
    expect(result.data[:host]).to eq("example.com")
    expect(result.data[:address]).to eq("203.0.113.9")
    expect(Network::Destination).to have_received(:call).with(host: "example.com")
    expect(Network::Tcp::Probe).to have_received(:call).with(ip: "203.0.113.9", port: 80, timeout: described_class::TIMEOUT)
  end

  it "lists open ports first, then by number, with the usual service name", :aggregate_failures do
    stub_probes(22 => attempt(:closed), 80 => attempt(:filtered), 443 => attempt(:open))
    rows = run.data[:rows]

    expect(rows.map(&:port)).to eq([443, 22, 80])
    expect(rows.map(&:service)).to eq(%w[https ssh http])
    expect(rows.first.ms).to eq(5)
  end

  it "keeps the service empty for unknown ports" do
    stub_probes(54_321 => attempt(:open))

    expect(described_class.call(host: "example.com", ports: "54321").data[:rows].first.service).to be_nil
  end

  it "counts the statuses" do
    stub_probes(22 => attempt(:open), 80 => attempt(:open), 443 => attempt(:filtered))

    expect(run.data[:counts]).to eq(open: 2, closed: 0, filtered: 1)
  end

  it "reads the ports from a variable and names an undefined one", :aggregate_failures do
    environment = create(:environment)
    create(:variable, environment:, key: "ports", value: "22,80")
    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
    allow(Network::Tcp::Probe).to receive(:call).and_return(Network::Tcp::Probe::Attempt.new(status: :open, ms: 5))

    expect(described_class.call(host: "example.com", ports: "{{ports}}", environment:).data[:rows].map(&:port)).to eq([22, 80])
    expect(described_class.call(host: "example.com", ports: "{{nope}}", environment:)).to have_attributes(error: :unresolved_variable)
  end

  it "resolves {{variables}} from the environment", :aggregate_failures do
    environment = create(:environment)
    create(:variable, environment:, key: "host", value: "api.example.com")
    stub_probes(22 => attempt(:open))
    result = described_class.call(host: "{{host}}", ports: "22", environment:)

    expect(result.data[:host]).to eq("api.example.com")
  end

  it "returns the target error without connecting", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call)
    result = described_class.call(host: "ftp://example.com", ports: "22")

    expect(result.error).to eq(:invalid)
    expect(Network::Tcp::Probe).not_to have_received(:call)
  end

  it "returns the port error without connecting", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call)
    result = described_class.call(host: "example.com", ports: "nope")

    expect(result.error).to eq(:invalid_ports)
    expect(Network::Destination).not_to have_received(:call)
  end

  it "returns the guard error without connecting", :aggregate_failures do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked, detail: "private"))
    allow(Network::Tcp::Probe).to receive(:call)
    result = run

    expect(result.error).to eq(:blocked)
    expect(Network::Tcp::Probe).not_to have_received(:call)
  end
end
