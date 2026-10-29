require "rails_helper"

RSpec.describe Network::Rdap::Client do
  let(:url) { "https://rdap.example.net/domain/example.com" }

  def get(deadline: nil)
    described_class.call(url:, deadline:)
  end

  def json(body = { "ldhName" => "EXAMPLE.COM" }, **options)
    { status: 200, body: body.to_json, headers: { "Content-Type" => "application/rdap+json" } }.merge(options)
  end

  it "returns the parsed document and asks for RDAP JSON", :aggregate_failures do
    stub = stub_request(:get, url).with(headers: { "Accept" => "application/rdap+json, application/json" }).to_return(json)
    result = get

    expect(result).to be_success
    expect(result.record).to eq("ldhName" => "EXAMPLE.COM")
    expect(stub).to have_been_requested
  end

  it "tells a 404 from other failures", :aggregate_failures do
    stub_request(:get, url).to_return(status: 404)

    expect(get).to have_attributes(failure?: true, error: :not_found)

    stub_request(:get, url).to_return(status: 500)

    expect(get).to have_attributes(failure?: true, error: :unavailable)
  end

  it "follows redirects, relative ones included, checking each one", :aggregate_failures do
    stub_request(:get, url).to_return(status: 301, headers: { "Location" => "/moved/example.com" })
    stub_request(:get, "https://rdap.example.net/moved/example.com").to_return(status: 302, headers: { "Location" => "https://other.example.org/domain/example.com" })
    stub_request(:get, "https://other.example.org/domain/example.com").to_return(json)
    allow(Network::SsrfPolicy).to receive(:check!).and_call_original

    expect(get).to be_success
    expect(Network::SsrfPolicy).to have_received(:check!).with("other.example.org")
  end

  it "gives up after too many redirects" do
    stub_request(:get, url).to_return(status: 302, headers: { "Location" => url })

    expect(get).to have_attributes(failure?: true, error: :unavailable)
    expect(a_request(:get, url)).to have_been_made.times(described_class::MAX_REDIRECTS + 1)
  end

  it "refuses to leave HTTPS, in the address or in a redirect", :aggregate_failures do
    stub_request(:get, url).to_return(status: 302, headers: { "Location" => "http://rdap.example.net/domain/example.com" })

    expect(get).to have_attributes(failure?: true, error: :unavailable)
    expect(described_class.call(url: "http://rdap.example.net/domain/example.com")).to have_attributes(failure?: true, error: :unavailable)
    expect(described_class.call(url: "not a url")).to have_attributes(failure?: true, error: :unavailable)
  end

  it "fails on a body that is not a JSON object", :aggregate_failures do
    stub_request(:get, url).to_return(status: 200, body: "<html>")

    expect(get).to have_attributes(failure?: true, error: :unavailable)

    stub_request(:get, url).to_return(status: 200, body: "[1]")

    expect(get).to have_attributes(failure?: true, error: :unavailable)
  end

  it "stops reading a body that is too large" do
    stub_const("#{described_class}::MAX_BYTES", 10)
    stub_request(:get, url).to_return(status: 200, body: { "name" => "x" * 100 }.to_json)

    expect(get).to have_attributes(failure?: true, error: :unavailable)
  end

  it "stops reading once the time is up" do
    stub_request(:get, url).to_return(json)
    allow_any_instance_of(described_class).to receive(:now).and_return(0, 0, 100) # rubocop:disable RSpec/AnyInstance

    expect(get(deadline: 10)).to have_attributes(failure?: true, error: :unavailable)
  end

  it "fails without connecting when the deadline has passed" do
    expect(get(deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) - 1)).to have_attributes(failure?: true, error: :unavailable)
    expect(a_request(:get, url)).not_to have_been_made
  end

  it "fails on a timeout or a connection that cannot be made", :aggregate_failures do
    stub_request(:get, url).to_timeout

    expect(get).to have_attributes(failure?: true, error: :unavailable)

    stub_request(:get, url).to_raise(Errno::ECONNREFUSED)

    expect(get).to have_attributes(failure?: true, error: :unavailable)
  end

  it "fails when the guard blocks the server" do
    allow(Network::SsrfPolicy).to receive(:check!).and_raise(Network::SsrfPolicy::Blocked)

    expect(get).to have_attributes(failure?: true, error: :unavailable)
    expect(a_request(:get, url)).not_to have_been_made
  end

  it "connects to the address the guard approved" do
    allow(Network::SsrfPolicy).to receive(:check!).and_return("93.184.216.34")
    allow(Net::HTTP).to receive(:start).and_call_original
    stub_request(:get, url).to_return(json)
    get

    expect(Net::HTTP).to have_received(:start).with("rdap.example.net", 443, hash_including(use_ssl: true, ipaddr: "93.184.216.34", verify_mode: OpenSSL::SSL::VERIFY_PEER))
  end
end
