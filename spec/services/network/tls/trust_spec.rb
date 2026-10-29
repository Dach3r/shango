require "rails_helper"

RSpec.describe Network::Tls::Trust do
  let(:root) { tls_root }
  let(:intermediate) { tls_certificate(subject: "/CN=Shango Test Intermediate", names: [], issuer: root, key: TlsCertificates::KEYS[:intermediate], ca: true) }
  let(:leaf) { tls_certificate(issuer: intermediate, issuer_key: TlsCertificates::KEYS[:intermediate]) }

  it "trusts a chain that leads to a known root" do
    expect(described_class.check([leaf, intermediate], store: tls_store(root))).to eq(status: "trusted", reason: nil, code: nil)
  end

  it "leaves the dates to the caller" do
    expired = tls_certificate(issuer: root, not_before: 2.years.ago, not_after: 1.year.ago)

    expect(described_class.check([expired], store: tls_store(root))[:status]).to eq("trusted")
  end

  it "tells why a chain is not trusted", :aggregate_failures do
    expect(described_class.check([tls_certificate], store: tls_store(root))).to include(status: "untrusted", reason: "self_signed")
    expect(described_class.check([leaf, intermediate, root], store: tls_store)).to include(reason: "untrusted_root")
    expect(described_class.check([leaf], store: tls_store(root))).to include(reason: "unknown_issuer")
  end

  it "keeps the code of any other error" do
    server = tls_certificate(subject: "/CN=Not a server", issuer: root)
    server.add_extension(OpenSSL::X509::ExtensionFactory.new(root, server).create_extension("extendedKeyUsage", "clientAuth"))
    server.sign(TlsCertificates::KEYS[:root], OpenSSL::Digest.new("SHA256"))

    expect(described_class.check([server], store: tls_store(root))).to eq(status: "untrusted", reason: "other", code: OpenSSL::X509::V_ERR_INVALID_PURPOSE)
  end

  it "checks against the roots of the system by default", :aggregate_failures do
    store = tls_store
    allow(OpenSSL::X509::Store).to receive(:new).and_return(store)
    allow(store).to receive(:set_default_paths)

    expect(described_class.check([tls_certificate])[:status]).to eq("untrusted")
    expect(store).to have_received(:set_default_paths)
  end
end
