require "rails_helper"

RSpec.describe Network::TlsChecks::Run do
  let(:root) { tls_root }
  let(:leaf) { tls_certificate(issuer: root) }

  def session(*chain, version: "TLSv1.3")
    Network::Tls::Handshake::Session.new(version:, cipher: "TLS_AES_256_GCM_SHA384", bits: 256, alpn: "h2", chain: chain.presence || [leaf, root])
  end

  def run(**options)
    described_class.call(host: "Example.com", port: "", protocol: "tls", **options)
  end

  before do
    allow(Network::Destination).to receive(:call).and_return(Result.success("203.0.113.9"))
    allow(Network::Tls::Handshake).to receive(:call).and_return(session)
    allow(Network::Tls::Trust).to receive(:default_store).and_return(tls_store(root))
  end

  it "connects to the approved address with the host name and describes the certificate", :aggregate_failures do
    result = run

    expect(result).to be_success
    expect(Network::Tls::Handshake).to have_received(:call).with(ip: "203.0.113.9", port: 443, sni: "example.com", protocol: "tls", timeout: described_class::TIMEOUT)
    expect(result.data).to include(host: "example.com", address: "203.0.113.9", port: 443, protocol: "tls", sni: "example.com", host_match: true, findings: [])
    expect(result.data[:session]).to eq(version: "TLSv1.3", cipher: "TLS_AES_256_GCM_SHA384", bits: 256, alpn: "h2")
    expect(result.data[:certificate]).to include(validity: "valid", days_left: 59, names: %w[example.com www.example.com])
    expect(result.data[:trust]).to eq(status: "trusted", reason: nil, code: nil)
    expect(result.data[:chain].pluck(:self_signed)).to eq([false, true])
  end

  it "keeps at most MAX_CHAIN certificates of the chain" do
    stub_const("#{described_class}::MAX_CHAIN", 1)

    expect(run.data[:chain].size).to eq(1)
  end

  it "sends no name to an IP address and checks the IP against the certificate", :aggregate_failures do
    allow(Network::Tls::Handshake).to receive(:call).and_return(session(tls_certificate(issuer: root, names: %w[203.0.113.9]), root))
    result = run(host: "203.0.113.9")

    expect(Network::Tls::Handshake).to have_received(:call).with(hash_including(sni: nil))
    expect(result.data).to include(sni: nil, host_match: true)
  end

  it "reports a bad certificate as findings, not as an error", :aggregate_failures do
    allow(Network::Tls::Handshake).to receive(:call).and_return(session(tls_certificate(names: %w[other.example.com], not_before: 2.years.ago, not_after: 3.days.ago)))
    result = run

    expect(result).to be_success
    expect(result.data).to include(host_match: false, trust: include(status: "untrusted", reason: "self_signed"))
    expect(result.data[:certificate]).to include(validity: "expired", days_left: -3)
    expect(result.data[:findings].pluck(:key)).to eq(%w[expired name_mismatch untrusted.self_signed])
  end

  describe "validity" do
    def validity(not_before, not_after)
      allow(Network::Tls::Handshake).to receive(:call).and_return(session(tls_certificate(issuer: root, not_before:, not_after:), root))
      run.data[:certificate][:validity]
    end

    it "tells a certificate that is not valid yet" do
      expect(validity(2.days.from_now, 90.days.from_now)).to eq("not_yet_valid")
    end

    it "warns in the last EXPIRING_DAYS of a long certificate", :aggregate_failures do
      expect(validity(80.days.ago, 10.days.from_now)).to eq("expiring")
      expect(validity(60.days.ago, 30.days.from_now)).to eq("valid")
    end

    it "warns in the last third of a short-lived certificate", :aggregate_failures do
      expect(validity(3.days.ago, 3.days.from_now)).to eq("valid")
      expect(validity(5.days.ago, 1.day.from_now)).to eq("expiring")
    end
  end

  it "uses the usual port of the protocol when none is given", :aggregate_failures do
    { "smtp" => 587, "imap" => 143, "pop3" => 110 }.each do |protocol, port|
      expect(run(protocol:).data).to include(port:, protocol:)
    end
  end

  it "uses direct TLS when no protocol is given" do
    expect(run(protocol: nil).data[:protocol]).to eq("tls")
  end

  it "reads the port from a variable" do
    environment = create(:environment)
    create(:variable, environment:, key: "port", value: "8443")

    expect(run(port: "{{port}}", environment:).data[:port]).to eq(8443)
  end

  it "validates the input before connecting", :aggregate_failures do
    expect(run(protocol: "ftp").error).to eq(:invalid_protocol)
    expect(run(port: "70000").error).to eq(:invalid_port)
    expect(run(port: "https").error).to eq(:invalid_port)
    expect(run(port: "{{nope}}")).to have_attributes(error: :unresolved_variable, data: { name: "nope" })
    expect(run(host: "ftp://example.com").error).to eq(:invalid)
    expect(Network::Tls::Handshake).not_to have_received(:call)
  end

  it "returns the guard error without connecting", :aggregate_failures do
    allow(Network::Destination).to receive(:call).and_return(Result.failure(error: :blocked, detail: "private"))

    expect(run.error).to eq(:blocked)
    expect(Network::Tls::Handshake).not_to have_received(:call)
  end

  it "turns connection problems into errors", :aggregate_failures do
    {
      Network::Tls::Handshake::Refused => :connection_refused, Network::Tls::Handshake::TimedOut => :connection_timeout,
      Network::Tls::StartTls::Refused => :starttls_refused
    }.each do |error, code|
      allow(Network::Tls::Handshake).to receive(:call).and_raise(error)

      expect(run.error).to eq(code)
    end
  end

  it "keeps the reason of a failed handshake" do
    allow(Network::Tls::Handshake).to receive(:call).and_raise(Network::Tls::Handshake::Failed, "wrong version number")

    expect(run).to have_attributes(error: :handshake_failed, data: { detail: "wrong version number" })
  end

  it "fails when the server sends no certificate" do
    allow(Network::Tls::Handshake).to receive(:call).and_return(Network::Tls::Handshake::Session.new(version: "TLSv1.2", cipher: "ADH", bits: 128, alpn: nil, chain: []))

    expect(run.error).to eq(:no_certificate)
  end
end
