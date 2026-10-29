require "rails_helper"

RSpec.describe Monitoring::Probes::Request do
  let(:project) { create(:project) }
  let(:environment) { create(:environment, project:) }
  let(:api_request) { create(:api_request, collection: create(:collection, project:), url: "{{base}}/health", headers: [{ "key" => "X-Token", "value" => "{{token}}", "enabled" => true }]) }
  let(:monitor) { create(:uptime_monitor, :request, project:, api_request:, environment:, timeout: 7, settings: { "mode" => "request", "expected_statuses" => "200" }) }

  before do
    create(:variable, environment:, key: "base", value: "https://api.example.com")
    create(:variable, environment:, key: "token", value: "s3cr3t-value", secret: true)
    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
  end

  it "sends the saved request with its secret variables and judges the status", :aggregate_failures do
    stub = stub_request(:get, "https://api.example.com/health").with(headers: { "X-Token" => "s3cr3t-value" }).to_return(status: 200, body: "a" * 100_000)
    outcome = Monitoring::Checks::Run.call(monitor)

    expect(stub).to have_been_requested
    expect(outcome).to have_attributes(status: "up", http_status: 200)
    expect(outcome.timings.keys).to eq(%w[dns tcp tls ttfb])
  end

  it "runs with the monitor's deadline, a small body cap and the strict resolver" do
    allow(ApiClient::Executor).to receive(:call).and_call_original
    stub_request(:get, "https://api.example.com/health").to_return(status: 200)
    described_class.call(monitor)

    expect(ApiClient::Executor).to have_received(:call).with(hash_including(deadline: 7, max_bytes: 64.kilobytes, resolve: described_class::RESOLVE))
  end

  it "is down for an unexpected status or a slow answer, masking secrets", :aggregate_failures do
    stub_request(:get, "https://api.example.com/health").to_return(status: [500, "Broke s3cr3t-value"])
    expect(described_class.call(monitor)).to have_attributes(error: "unexpected_status", http_status: 500, detail: "500 Broke ••••••")

    monitor.update!(settings: monitor.settings.merge("expected_statuses" => "500", "max_response_ms" => 1))
    stub_request(:get, "https://api.example.com/health").to_return { sleep 0.01 and { status: 500 } }
    expect(described_class.call(monitor)).to have_attributes(error: "slow_response")
  end

  it "maps transport errors and masks their message", :aggregate_failures do
    {
      Faraday::TimeoutError.new("slow") => "connection_timeout", Faraday::SSLError.new("bad cert") => "tls_failed",
      Faraday::ConnectionFailed.new(Errno::ECONNREFUSED.new) => "connection_refused", Faraday::ConnectionFailed.new("weird") => "connection_failed",
      RuntimeError.new("s3cr3t-value leaked") => "connection_failed"
    }.each do |error, cause|
      stub_request(:get, "https://api.example.com/health").to_raise(error)
      outcome = described_class.call(monitor)
      expect(outcome.error).to eq(cause)
      expect(outcome.detail.to_s).not_to include("s3cr3t-value")
    end
  end

  it "refuses cloud metadata addresses and blocked or unknown hosts on every hop", :aggregate_failures do
    allow(Network::Destination).to receive(:call).and_return(Result.success("169.254.169.254"))
    expect(described_class.call(monitor)).to have_attributes(error: "blocked")
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked, detail: "private"))
    expect(described_class.call(monitor)).to have_attributes(error: "blocked", detail: "private")
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :unresolved))
    expect(described_class.call(monitor)).to have_attributes(error: "unresolved")
  end

  it "is down when the request, the environment or a variable is missing", :aggregate_failures do
    monitor.update_columns(api_request_id: nil)
    expect(described_class.call(monitor.reload)).to have_attributes(error: "request_missing")

    monitor.update_columns(api_request_id: api_request.id, environment_id: nil)
    expect(described_class.call(monitor.reload)).to have_attributes(error: "environment_missing")

    api_request.update!(url: "https://api.example.com/{{missing}}")
    monitor.update_columns(environment_required: false)
    expect(described_class.call(monitor.reload)).to have_attributes(error: "unresolved_variable", detail: "missing")

    api_request.update!(url: "https://api.example.com/health", headers: [{ "key" => "X-Other", "value" => "{{other}}", "enabled" => true }])
    expect(described_class.call(monitor.reload)).to have_attributes(error: "unresolved_variable", detail: "other")
  end

  it "tells an authentication problem from a request that cannot be built", :aggregate_failures do
    api_request.update!(auth_type: "bearer", auth_config: {})
    expect(described_class.call(monitor)).to have_attributes(error: "auth_failed", detail: "Missing token")

    api_request.update!(url: "https://api.example.com/health", headers: [])
    monitor.update_columns(environment_id: nil, environment_required: false)
    expect(described_class.call(monitor.reload)).to have_attributes(error: "auth_failed")

    api_request.update!(auth_type: "none", url: "  ")
    expect(described_class.call(monitor.reload)).to have_attributes(error: "invalid_request")
  end
end
