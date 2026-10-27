require "rails_helper"

RSpec.describe Network::Dns::Transport do
  let(:servers) { [] }

  after { servers.each(&:close) }

  def free_port(kind)
    socket = kind == :udp ? UDPSocket.new : TCPServer.new("127.0.0.1", 0)
    socket.bind("127.0.0.1", 0) if kind == :udp
    port = socket.addr[1]
    socket.close
    port
  end

  # Loopback UDP server that answers the first datagram with the block's result (or stays silent).
  def udp_server(&reply)
    server = UDPSocket.new
    server.bind("127.0.0.1", 0)
    servers << server
    thread = Thread.new do
      Thread.current.report_on_exception = false
      data, (_family, port, _host, ip) = server.recvfrom(512)
      server.send(reply.call(data), 0, ip, port) if reply
    rescue IOError
      nil
    end
    [server.addr[1], thread]
  end

  # Loopback TCP server; the block receives the accepted socket.
  def tcp_server(&handler)
    server = TCPServer.new("127.0.0.1", 0)
    servers << server
    thread = Thread.new do
      Thread.current.report_on_exception = false
      client = server.accept
      handler.call(client)
      client.close
    rescue IOError
      nil
    end
    [server.addr[1], thread]
  end

  describe ".udp" do
    it "sends the payload and returns the reply", :aggregate_failures do
      port, = udp_server { |data| data.reverse }

      expect(described_class.udp(ip: "127.0.0.1", port:, payload: "abc", timeout: 1)).to eq("cba")
    end

    it "raises TimedOut when nothing answers" do
      port, = udp_server

      expect { described_class.udp(ip: "127.0.0.1", port:, payload: "abc", timeout: 0.1) }.to raise_error(described_class::TimedOut)
    end

    it "raises Failed when the port is closed" do
      expect { described_class.udp(ip: "127.0.0.1", port: free_port(:udp), payload: "abc", timeout: 1) }.to raise_error(described_class::Failed)
    end
  end

  describe ".tcp" do
    it "frames the payload with its length and returns the reply", :aggregate_failures do
      received = nil
      port, thread = tcp_server do |client|
        length = client.read(2).unpack1("n")
        received = client.read(length)
        reply = "pong"
        client.write([reply.bytesize].pack("n"))
        client.flush
        sleep(0.05)
        client.write(reply)
      end

      expect(described_class.tcp(ip: "127.0.0.1", port:, payload: "ping", timeout: 2)).to eq("pong")
      thread.join
      expect(received).to eq("ping")
    end

    it "raises Failed when the server closes the connection" do
      port, = tcp_server { |client| client.read(2) }

      expect { described_class.tcp(ip: "127.0.0.1", port:, payload: "ping", timeout: 1) }.to raise_error(described_class::Failed)
    end

    it "raises TimedOut when the server never answers" do
      port, = tcp_server { |_client| sleep(0.5) }

      expect { described_class.tcp(ip: "127.0.0.1", port:, payload: "ping", timeout: 0.1) }.to raise_error(described_class::TimedOut)
    end

    it "raises Failed when the connection is refused" do
      expect { described_class.tcp(ip: "127.0.0.1", port: free_port(:tcp), payload: "ping", timeout: 1) }.to raise_error(described_class::Failed)
    end

    it "raises TimedOut when the connection attempt times out" do
      allow(Socket).to receive(:tcp).and_raise(Errno::ETIMEDOUT)

      expect { described_class.tcp(ip: "127.0.0.1", payload: "ping", timeout: 1) }.to raise_error(described_class::TimedOut)
    end
  end
end
