# Throwaway certificates for TLS specs: a root, and leaves or intermediates signed by it. Keys are generated once per run.
module TlsCertificates
  KEYS = Hash.new { |keys, name| keys[name] = name == :ec ? OpenSSL::PKey::EC.generate("prime256v1") : OpenSSL::PKey::RSA.new(name == :weak ? 1024 : 2048) }

  def tls_root(name: "Shango Test Root")
    tls_certificate(subject: "/CN=#{name}/O=Shango", key: KEYS[:root], ca: true)
  end

  # Signed by `issuer` (with `issuer_key`), or self-signed when no issuer is given.
  def tls_certificate(subject: "/CN=example.com", names: %w[example.com www.example.com], issuer: nil, issuer_key: KEYS[:root], key: KEYS[:leaf],
                      not_before: 30.days.ago, not_after: 60.days.from_now, digest: "SHA256", ca: false)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 0x1F
    cert.subject = OpenSSL::X509::Name.parse(subject)
    cert.issuer = issuer ? issuer.subject : cert.subject
    cert.public_key = key
    cert.not_before = not_before
    cert.not_after = not_after
    extensions = OpenSSL::X509::ExtensionFactory.new(issuer || cert, cert)
    cert.add_extension(extensions.create_extension("basicConstraints", ca ? "CA:TRUE" : "CA:FALSE", true))
    cert.add_extension(extensions.create_extension("keyUsage", ca ? "keyCertSign,cRLSign" : "digitalSignature,keyEncipherment", true))
    cert.add_extension(extensions.create_extension("subjectKeyIdentifier", "hash"))
    cert.add_extension(extensions.create_extension("subjectAltName", names.map { |name| name.match?(/\A[\d.:]+\z/) ? "IP:#{name}" : "DNS:#{name}" }.join(","))) if names.any?
    cert.sign(issuer ? issuer_key : key, OpenSSL::Digest.new(digest))
    cert
  end

  def tls_store(*roots)
    OpenSSL::X509::Store.new.tap { |store| roots.each { |root| store.add_cert(root) } }
  end
end

RSpec.configure { |config| config.include TlsCertificates }
