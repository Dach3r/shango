require "rails_helper"

RSpec.describe Network::Tls::Certificate do
  let(:root) { tls_root }

  it "describes a certificate as plain data", :aggregate_failures do
    leaf = tls_certificate(issuer: root, not_before: Time.utc(2026, 1, 1), not_after: Time.utc(2026, 4, 1))
    data = described_class.describe(leaf)

    expect(data).to include(subject: { name: "example.com", organization: nil }, issuer: { name: "Shango Test Root", organization: "Shango" }, self_signed: false)
    expect(data).to include(names: %w[example.com www.example.com], names_count: 2, not_before: "2026-01-01T00:00:00Z", not_after: "2026-04-01T00:00:00Z")
    expect(data).to include(serial: "1F", key: { type: "RSA", bits: 2048, curve: nil }, signature: "sha256WithRSAEncryption")
    expect(data[:sha256]).to match(/\A(\h\h:){31}\h\h\z/)
  end

  it "names an elliptic curve key and keeps IP addresses among the names", :aggregate_failures do
    data = described_class.describe(tls_certificate(key: TlsCertificates::KEYS[:ec], names: %w[203.0.113.9 example.com]))

    expect(data[:key]).to eq(type: "EC", bits: 256, curve: "P-256")
    expect(data[:names]).to eq(%w[203.0.113.9 example.com])
    expect(data[:self_signed]).to be(true)
  end

  it "keeps an unknown curve name as it comes" do
    key = OpenSSL::PKey::EC.generate("secp256k1")

    expect(described_class.describe(tls_certificate(key:))[:key]).to eq(type: "EC", bits: 256, curve: "secp256k1")
  end

  it "names other keys by their algorithm" do
    key = OpenSSL::PKey.generate_key("ED25519")
    cert = tls_certificate(key:, issuer: root)

    expect(described_class.describe(cert)[:key]).to eq(type: "ED25519", bits: nil, curve: nil)
  end

  it "keeps at most MAX_NAMES names but counts them all", :aggregate_failures do
    stub_const("#{described_class}::MAX_NAMES", 1)
    data = described_class.describe(tls_certificate)

    expect(data[:names]).to eq(["example.com"])
    expect(data[:names_count]).to eq(2)
  end

  it "leaves out names that are neither DNS names nor IP addresses" do
    cert = tls_certificate(names: [])
    cert.add_extension(OpenSSL::X509::ExtensionFactory.new(cert, cert).create_extension("subjectAltName", "email:ops@example.com,DNS:example.com"))

    expect(described_class.describe(cert)[:names]).to eq(["example.com"])
  end

  it "has no names without a subjectAltName extension" do
    expect(described_class.describe(tls_certificate(names: []))).to include(names: [], names_count: 0)
  end

  it "falls back to the organization and then to the whole name", :aggregate_failures do
    expect(described_class.entity(OpenSSL::X509::Name.parse("/O=Acme/C=US"))).to eq(name: "Acme", organization: "Acme")
    expect(described_class.entity(OpenSSL::X509::Name.parse("/C=US/L=Springfield"))).to eq(name: "L=Springfield,C=US", organization: nil)
  end

  it "summarizes a certificate of the chain" do
    cert = tls_certificate(issuer: root, not_after: Time.utc(2026, 4, 1))

    expect(described_class.summarize(cert)).to eq(subject: { name: "example.com", organization: nil }, issuer: { name: "Shango Test Root", organization: "Shango" },
                                                  not_after: "2026-04-01T00:00:00Z", self_signed: false)
  end
end
