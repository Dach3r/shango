require "rails_helper"

RSpec.describe Network::Tls::Handshake do
  let(:servers) { [] }
  let(:leaf) { tls_certificate }

  after { servers.each(&:close) }

  def context
    OpenSSL::SSL::SSLContext.new.tap do |context|
      context.cert = leaf
      context.key = TlsCertificates::KEYS[:leaf]
      context.alpn_select_cb = ->(protocols) { protocols.first }
      context.servername_cb = ->((socket, name)) { @sni = name; socket.context }
    end
  end

  # Loopback server; the block receives the accepted socket before the TLS handshake (for the plain-text part).
  def tls_server(tls: true, &before)
    server = TCPServer.new("127.0.0.1", 0)
    servers << server
    Thread.new do
      Thread.current.report_on_exception = false
      client = server.accept
      before&.call(client)
      next client.close unless tls

      ssl = OpenSSL::SSL::SSLSocket.new(client, context)
      ssl.accept
      ssl.read
      ssl.close
    rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
      nil
    end
    server.addr[1]
  end

  def handshake(port, protocol: "tls", sni: "example.com", timeout: 2)
    described_class.call(ip: "127.0.0.1", port:, sni:, protocol:, timeout:)
  end

  it "returns the negotiated session and the certificates, sending the name and offering ALPN", :aggregate_failures do
    session = handshake(tls_server)

    expect(session).to have_attributes(version: "TLSv1.3", alpn: "h2")
    expect(session.cipher).to be_present
    expect(session.bits).to be_positive
    expect(session.chain.map(&:to_der)).to eq([leaf.to_der])
    expect(@sni).to eq("example.com")
  end

  it "sends no name for an IP address" do
    handshake(tls_server, sni: nil)

    expect(@sni).to be_nil
  end

  it "upgrades a mail connection with STARTTLS first, without ALPN", :aggregate_failures do
    port = tls_server do |client|
      client.write("+OK ready\r\n")
      client.gets
      client.write("+OK go\r\n")
    end
    session = handshake(port, protocol: "pop3")

    expect(session.chain.first.to_der).to eq(leaf.to_der)
    expect(session.alpn).to be_nil
  end

  it "raises Refused when nothing listens" do
    port = TCPServer.new("127.0.0.1", 0).then { |server| server.addr[1].tap { server.close } }

    expect { handshake(port) }.to raise_error(described_class::Refused)
  end

  it "raises TimedOut when the server never answers the handshake" do
    port = tls_server(tls: false) { sleep 1 }

    expect { handshake(port, timeout: 0.2) }.to raise_error(described_class::TimedOut)
  end

  it "raises TimedOut when the connection cannot be made in time" do
    allow(Socket).to receive(:tcp).and_raise(Errno::ETIMEDOUT)

    expect { handshake(1) }.to raise_error(described_class::TimedOut)
  end

  it "raises Failed with the reason when the port does not speak TLS" do
    port = tls_server(tls: false) { |client| client.write("HTTP/1.1 400 Bad Request\r\n\r\n") }

    expect { handshake(port) }.to raise_error(described_class::Failed, /wrong version number|packet length too long|record layer failure/)
  end

  it "raises Failed when the server hangs up during the dialog" do
    port = tls_server(tls: false)

    expect { handshake(port, protocol: "smtp") }.to raise_error(described_class::Failed)
  end
end
