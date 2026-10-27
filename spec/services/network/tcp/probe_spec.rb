require "rails_helper"

RSpec.describe Network::Tcp::Probe do
  def probe(port, timeout: 1)
    described_class.call(ip: "127.0.0.1", port:, timeout:)
  end

  it "reports an accepting port as open", :aggregate_failures do
    server = TCPServer.new("127.0.0.1", 0)
    attempt = probe(server.addr[1])

    expect(attempt.status).to eq(:open)
    expect(attempt.ms).to be_a(Integer)
  ensure
    server&.close
  end

  it "reports a refused connection as closed" do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close

    expect(probe(port).status).to eq(:closed)
  end

  it "reports a timeout as filtered" do
    allow(Socket).to receive(:tcp).and_raise(Errno::ETIMEDOUT)

    expect(probe(81).status).to eq(:filtered)
  end

  it "reports an unreachable host as filtered" do
    allow(Socket).to receive(:tcp).and_raise(Errno::EHOSTUNREACH)

    expect(probe(81).status).to eq(:filtered)
  end

  it "connects to the address it is given, with the timeout, without sending anything" do
    allow(Socket).to receive(:tcp)

    probe(8080, timeout: 2)

    expect(Socket).to have_received(:tcp).with("127.0.0.1", 8080, connect_timeout: 2)
  end
end
