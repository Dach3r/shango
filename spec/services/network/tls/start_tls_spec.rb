require "rails_helper"

RSpec.describe Network::Tls::StartTls do
  let(:pair) { Socket.pair(:UNIX, :STREAM) }
  let(:client) { pair.first }
  let(:server) { pair.last }

  after { pair.each(&:close) }

  # The server's replies are written up front; the client reads them line by line as the dialog goes.
  def dialog(protocol, replies, timeout: 1)
    server.write(replies)
    described_class.call(socket: client, protocol:, deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout)
  end

  def sent
    server.read_nonblock(1000)
  end

  describe "smtp" do
    it "says EHLO and asks for STARTTLS once it is offered", :aggregate_failures do
      dialog("smtp", "220-mx.example.com ESMTP\r\n220 ready\r\n250-mx.example.com\r\n250-SIZE 1000\r\n250 starttls\r\n220 go ahead\r\n")

      expect(sent).to eq("EHLO shango.invalid\r\nSTARTTLS\r\n")
    end

    it "refuses a server that does not offer STARTTLS", :aggregate_failures do
      expect { dialog("smtp", "220 ready\r\n250-mx.example.com\r\n250 SIZE 1000\r\n") }.to raise_error(described_class::Refused)
      expect(sent).to eq("EHLO shango.invalid\r\n")
    end

    it "refuses unexpected replies", :aggregate_failures do
      expect { dialog("smtp", "554 go away\r\n") }.to raise_error(described_class::Refused)
      expect { dialog("smtp", "220 ready\r\n250 STARTTLS\r\n454 TLS not available\r\n") }.to raise_error(described_class::Refused)
    end
  end

  describe "imap" do
    it "asks for STARTTLS and waits for the tagged answer", :aggregate_failures do
      dialog("imap", "* OK IMAP4rev1 ready\r\n* CAPABILITY IMAP4rev1 STARTTLS\r\na1 OK Begin TLS\r\n")

      expect(sent).to eq("a1 STARTTLS\r\n")
    end

    it "accepts a preauthenticated greeting" do
      expect { dialog("imap", "* PREAUTH ready\r\na1 OK go\r\n") }.not_to raise_error
    end

    it "refuses a bad greeting or a refusal", :aggregate_failures do
      expect { dialog("imap", "* BYE busy\r\n") }.to raise_error(described_class::Refused)
      expect { dialog("imap", "* OK ready\r\na1 NO not now\r\n") }.to raise_error(described_class::Refused)
    end
  end

  describe "pop3" do
    it "asks for STLS", :aggregate_failures do
      dialog("pop3", "+OK POP3 ready\r\n+OK begin TLS\r\n")

      expect(sent).to eq("STLS\r\n")
    end

    it "refuses a bad greeting or a refusal", :aggregate_failures do
      expect { dialog("pop3", "-ERR busy\r\n") }.to raise_error(described_class::Refused)
      expect { dialog("pop3", "+OK ready\r\n-ERR no TLS\r\n") }.to raise_error(described_class::Refused)
    end
  end

  it "refuses a line longer than MAX_LINE" do
    expect { dialog("pop3", "+OK #{"x" * described_class::MAX_LINE}\r\n") }.to raise_error(described_class::Refused)
  end

  it "times out when the server stays silent" do
    expect { dialog("pop3", "", timeout: 0.1) }.to raise_error(Network::Tls::Handshake::TimedOut)
  end

  it "fails when the server hangs up" do
    server.close_write

    expect { dialog("pop3", "") }.to raise_error(EOFError)
  end
end
