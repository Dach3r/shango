require "rails_helper"

RSpec.describe Network::Pings::Run do
  def attempt(status, ms = 10)
    Network::Tcp::Probe::Attempt.new(status:, ms:)
  end

  def stub_probes(*attempts)
    allow(Network::Tcp::Probe).to receive(:call).and_return(*attempts)
  end

  def run(**options)
    described_class.call(host: "Example.com", port: "443", attempts: "4", **options)
  end

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "probes the approved address once per attempt", :aggregate_failures do
    stub_probes(attempt(:open))
    result = run

    expect(result).to be_success
    expect(result.data).to include(host: "example.com", address: "203.0.113.9", port: 443)
    expect(result.data[:attempts].size).to eq(4)
    expect(Network::Tcp::Probe).to have_received(:call).with(ip: "203.0.113.9", port: 443, timeout: described_class::TIMEOUT).exactly(4).times
  end

  it "reads the port and the attempts from variables", :aggregate_failures do
    environment = create(:environment)
    create(:variable, environment:, key: "port", value: "8443")
    create(:variable, environment:, key: "tries", value: "2")
    stub_probes(attempt(:open))
    result = run(port: "{{port}}", attempts: "{{tries}}", environment:)

    expect(result.data).to include(port: 8443)
    expect(result.data[:attempts].size).to eq(2)
  end

  it "names an undefined variable in the port or the attempts", :aggregate_failures do
    expect(run(port: "{{nope}}")).to have_attributes(error: :unresolved_variable, data: { name: "nope" })
    expect(run(attempts: "{{nope}}")).to have_attributes(error: :unresolved_variable, data: { name: "nope" })
  end

  it "summarizes latency and loss", :aggregate_failures do
    stub_probes(attempt(:open, 10), attempt(:open, 30), attempt(:filtered, 2000), attempt(:open, 20))

    expect(run.data[:summary]).to eq(sent: 4, received: 3, loss: 25, min: 10, max: 30, avg: 20, open: 3, stopped: false)
  end

  it "counts a refused connection as an answer", :aggregate_failures do
    stub_probes(attempt(:closed, 5))
    summary = run.data[:summary]

    expect(summary).to include(received: 4, loss: 0, open: 0)
  end

  it "reports no latency when nothing answered", :aggregate_failures do
    stub_probes(attempt(:filtered, 2000))
    summary = run(attempts: "3").data[:summary]

    expect(summary).to include(sent: 3, received: 0, loss: 100, min: nil, avg: nil, max: nil, stopped: false)
  end

  it "stops after consecutive timeouts", :aggregate_failures do
    stub_probes(attempt(:filtered, 2000))
    result = run(attempts: "10")

    expect(result.data[:attempts].size).to eq(described_class::MAX_CONSECUTIVE_TIMEOUTS)
    expect(result.data[:summary]).to include(stopped: true, loss: 100)
  end

  it "does not stop when timeouts are not consecutive" do
    stub_probes(*([attempt(:filtered), attempt(:open)] * 5))

    expect(run(attempts: "10").data[:attempts].size).to eq(10)
  end

  it "uses the defaults for blank port and attempts", :aggregate_failures do
    stub_probes(attempt(:open))
    result = described_class.call(host: "example.com", port: " ", attempts: nil)

    expect(result.data[:port]).to eq(443)
    expect(result.data[:attempts].size).to eq(4)
  end

  it "validates the port", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call)

    %w[0 65536 abc 80.5 -1].each do |port|
      expect(run(port:).error).to eq(:invalid_port), port
    end
    expect(Network::Tcp::Probe).not_to have_received(:call)
  end

  it "validates the number of attempts", :aggregate_failures do
    %w[0 11 many 2.5].each do |attempts|
      result = run(attempts:)

      expect(result.error).to eq(:invalid_attempts), attempts
      expect(result.data[:max]).to eq(described_class::MAX_ATTEMPTS)
    end
  end

  it "returns the target error", :aggregate_failures do
    allow(Network::Tcp::Probe).to receive(:call)

    expect(described_class.call(host: "https://example.com").error).to eq(:invalid)
    expect(Network::Tcp::Probe).not_to have_received(:call)
  end

  it "returns the guard error without connecting", :aggregate_failures do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :unresolved))
    allow(Network::Tcp::Probe).to receive(:call)

    expect(run.error).to eq(:unresolved)
    expect(Network::Tcp::Probe).not_to have_received(:call)
  end

  it "resolves {{variables}} from the environment" do
    environment = create(:environment)
    create(:variable, environment:, key: "host", value: "api.example.com")
    stub_probes(attempt(:open))

    expect(run(host: "{{host}}", environment:).data[:host]).to eq("api.example.com")
  end
end
