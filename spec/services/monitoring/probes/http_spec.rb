require "rails_helper"

RSpec.describe Monitoring::Probes::Http do
  let(:project) { create(:project) }
  let(:settings) { { "url" => "https://example.com/health" } }
  let(:monitor) { create(:uptime_monitor, project:, settings:) }

  def probe(record = monitor)
    described_class.call(record)
  end

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "is up with an expected status and keeps the time and phases", :aggregate_failures do
    stub = stub_request(:get, "https://example.com/health").with(headers: { "User-Agent" => "Shango monitor" }).to_return(status: 204, body: "ignored")
    outcome = probe

    expect(stub).to have_been_requested
    expect(outcome).to have_attributes(status: "up", http_status: 204, error: nil)
    expect(outcome.response_ms).to be_a(Integer)
    expect(outcome.timings.keys).to eq(%w[dns tcp tls ttfb])
  end

  it "sends HEAD when asked, pinned to the checked address without a proxy", :aggregate_failures do
    created = []
    allow(Net::HTTP).to receive(:new).and_wrap_original { |original, *args| original.call(*args).tap { |http| created << http } }
    monitor.update!(settings: settings.merge("http_method" => "HEAD"))
    stub = stub_request(:head, "https://example.com/health").to_return(status: 200)

    expect(probe).to be_up
    expect(stub).to have_been_requested
    expect(created.first).to have_attributes(ipaddr: "203.0.113.9", proxy?: false, use_ssl?: true)
  end

  it "follows redirects and judges the last answer", :aggregate_failures do
    monitor.update!(settings: { "url" => "http://example.com", "expected_statuses" => "200" })
    stub_request(:get, "http://example.com/").to_return(status: 301, headers: { "Location" => "https://example.com/home" })
    stub_request(:get, "https://example.com/home").to_return(status: [503, "Service Unavailable"])

    expect(probe).to have_attributes(status: "down", error: "unexpected_status", http_status: 503, detail: "503 Service Unavailable")
  end

  it "is down when slower than the limit" do
    monitor.update!(settings: settings.merge("max_response_ms" => 1))
    stub_request(:get, "https://example.com/health").to_return do
      sleep 0.01
      { status: 200 }
    end

    expect(probe).to have_attributes(status: "down", error: "slow_response", http_status: 200)
  end

  it "takes https when the URL has no scheme" do
    monitor.update!(settings: { "url" => "example.com/health" })
    stub_request(:get, "https://example.com/health").to_return(status: 200)

    expect(probe).to be_up
  end

  it "accepts a status in any listed range" do
    monitor.update!(settings: settings.merge("expected_statuses" => "200,401-403"))
    stub_request(:get, "https://example.com/health").to_return(status: 401)

    expect(probe).to be_up
  end

  it "resolves variables of its environment and refuses secret ones", :aggregate_failures do
    environment = create(:environment, project:)
    create(:variable, environment:, key: "base_url", value: "https://api.example.com")
    create(:variable, environment:, key: "token", value: "abc", secret: true)
    stub_request(:get, "https://api.example.com/health").to_return(status: 200)
    monitor.update!(environment:, settings: { "url" => "{{base_url}}/health" })

    expect(probe).to be_up

    monitor.update!(settings: { "url" => "{{base_url}}/health?token={{token}}" })

    expect(probe).to have_attributes(status: "down", error: "secret_variable", detail: "token")
  end

  it "is down when the environment it needs was deleted", :aggregate_failures do
    monitor.update!(environment: create(:environment, project:))
    monitor.environment.destroy

    expect(probe(monitor.reload)).to have_attributes(status: "down", error: "environment_missing")
  end

  it "is down for URLs it cannot request", :aggregate_failures do
    ["ftp://example.com", "https://exa mple.com", "https://user:pass@example.com", "https://#{"a" * 2048}.com", "https://exa<mple.com"].each do |url|
      monitor.settings = { "url" => url }

      expect(probe).to have_attributes(status: "down", error: "invalid_url"), url
    end
  end

  it "stops on redirects it cannot or should not follow", :aggregate_failures do
    stub_request(:get, "https://example.com/health").to_return(status: 302, headers: { "Location" => "ftp://example.com/file" })

    expect(probe).to have_attributes(error: "invalid_redirect", detail: "ftp://example.com/file")

    stub_request(:get, "https://example.com/health").to_return(status: 302, headers: { "Location" => "/health#again" })

    expect(probe).to have_attributes(error: "redirect_loop", detail: "https://example.com/health")

    stub_const("#{described_class}::MAX_REDIRECTS", 1)
    stub_request(:get, "https://example.com/health").to_return(status: 302, headers: { "Location" => "/a" })
    stub_request(:get, "https://example.com/a").to_return(status: 302, headers: { "Location" => "/b" })

    expect(probe.error).to eq("too_many_redirects")
  end

  it "does not follow a redirect without a location" do
    stub_request(:get, "https://example.com/health").to_return(status: 304)

    expect(probe).to have_attributes(status: "up", http_status: 304)
  end

  it "tells why there was no answer", :aggregate_failures do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked, detail: "example.com resolves to a private address (10.0.0.1)"))

    expect(probe).to have_attributes(error: "blocked", detail: "example.com resolves to a private address (10.0.0.1)")

    allow(Network::Destination).to receive(:call).and_return(Result.success("169.254.169.254"))

    expect(probe).to have_attributes(error: "blocked", detail: "example.com resolves to a cloud metadata address (169.254.169.254)")

    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
    {
      Errno::ECONNREFUSED => ["connection_refused", nil], Net::OpenTimeout => ["connection_timeout", nil],
      OpenSSL::SSL::SSLError.new("SSL_connect returned=1 state=error: certificate verify failed (certificate has expired)") => ["tls_failed", "certificate verify failed (certificate has expired)"],
      EOFError.new("end of file reached") => ["connection_failed", "end of file reached"]
    }.each do |error, (cause, detail)|
      stub_request(:get, "https://example.com/health").to_raise(error)

      expect(probe).to have_attributes(status: "down", error: cause, detail:), cause
    end
  end

  it "gives up when the deadline has passed before a hop" do
    monitor.update!(timeout: 1)
    stub_request(:get, "https://example.com/health").to_return do
      sleep 1.05
      { status: 302, headers: { "Location" => "/next" } }
    end

    expect(probe).to have_attributes(error: "connection_timeout")
  end
end
