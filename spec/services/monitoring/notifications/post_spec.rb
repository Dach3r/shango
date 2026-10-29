require "rails_helper"

RSpec.describe Monitoring::Notifications::Post do
  let(:uri) { URI("https://hooks.example.com/secret-path") }

  def post(target = uri)
    described_class.call(uri: target, body: '{"a":1}', headers: { "X-Test" => "1" })
  end

  before { allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9")) }

  it "POSTs JSON pinned to the checked address, without a proxy", :aggregate_failures do
    created = []
    allow(Net::HTTP).to receive(:new).and_wrap_original { |original, *args| original.call(*args).tap { |http| created << http } }
    stub = stub_request(:post, uri.to_s).with(body: '{"a":1}', headers: { "Content-Type" => "application/json", "X-Test" => "1", "User-Agent" => "Shango notifications" }).to_return(status: 204)

    expect(post).to be_success
    expect(stub).to have_been_requested
    expect(created.first).to have_attributes(ipaddr: "203.0.113.9", proxy?: false, use_ssl?: true, open_timeout: 10)
  end

  it "refuses invalid URLs and blocked or metadata addresses for good", :aggregate_failures do
    expect(post(URI("ftp://example.com"))).to have_attributes(error: :invalid_url, data: { permanent: true })
    expect(post(URI("https://u:p@example.com"))).to have_attributes(error: :invalid_url)
    allow(Network::Destination).to receive(:call).and_return(Result.success("169.254.169.254"))
    expect(post).to have_attributes(error: :blocked, data: { permanent: true })
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked))
    expect(post).to have_attributes(error: :blocked, data: { permanent: true })
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :unresolved))
    expect(post).to have_attributes(error: :unresolved, data: { permanent: false })
  end

  it "tells a client error, which retrying cannot fix, from a server error", :aggregate_failures do
    stub_request(:post, uri.to_s).to_return({ status: 404 }, { status: 408 }, { status: 502 })

    expect(post).to have_attributes(error: :unexpected_status, data: { detail: "404", permanent: true })
    expect(post).to have_attributes(error: :unexpected_status, data: { detail: "408", permanent: false })
    expect(post).to have_attributes(error: :unexpected_status, data: { detail: "502", permanent: false })
  end

  it "reads how long to wait from a 429" do
    stub_request(:post, uri.to_s).to_return(status: 429, headers: { "Retry-After" => "1.2" })

    expect(post).to have_attributes(error: :rate_limited, data: { detail: "429", retry_after: 2 })
  end

  it "maps network failures without the URL", :aggregate_failures do
    { Errno::ECONNREFUSED => :connection_refused, Net::OpenTimeout => :connection_timeout, SocketError => :connection_failed }.each do |error, key|
      stub_request(:post, uri.to_s).to_raise(error)
      expect(post).to have_attributes(error: key)
    end
    stub_request(:post, uri.to_s).to_raise(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 state=error: certificate verify failed"))
    expect(post).to have_attributes(error: :tls_failed, data: { detail: "certificate verify failed" })
    stub_request(:post, uri.to_s).to_raise(IOError.new("https://hooks.example.com/secret-path broke"))
    expect(post.data[:detail]).to eq("IOError")
  end
end
