require "rails_helper"

RSpec.describe Network::Dns::Query do
  def record(type, *args)
    Resolv::DNS::Resource::IN.const_get(type).new(*args)
  end

  # Builds the wire reply for a query payload, with `answers` as [ttl, resource] pairs.
  def reply_to(payload, answers: [], rcode: Resolv::DNS::RCode::NoError, tc: 0, id: nil)
    question = Resolv::DNS::Message.decode(payload)
    Resolv::DNS::Message.new(id || question.id).tap do |message|
      message.qr = 1
      message.rcode = rcode
      message.tc = tc
      question.each_question { |name, type| message.add_question(name, type) }
      answers.each { |ttl, data| message.add_answer("example.com", ttl, data) }
    end.encode
  end

  def stub_udp(**options)
    allow(Network::Dns::Transport).to receive(:udp) { |payload:, **| reply_to(payload, **options) }
  end

  def query(type: "A", **options)
    described_class.call(ip: "1.1.1.1", name: "example.com", type:, **options)
  end

  describe "answers" do
    it "returns the records of the asked type with the lowest TTL", :aggregate_failures do
      stub_udp(answers: [[300, record(:A, "93.184.216.34")], [120, record(:A, "93.184.216.35")]])
      answer = query

      expect(answer.status).to eq(:ok)
      expect(answer.answers).to eq(["93.184.216.34", "93.184.216.35"])
      expect(answer.ttl).to eq(120)
      expect(answer.ms).to be_a(Integer)
    end

    it "formats every supported record type", :aggregate_failures do
      records = {
        "AAAA" => [record(:AAAA, "2606:2800:220:1::1"), "2606:2800:220:1::1"],
        "CNAME" => [record(:CNAME, Resolv::DNS::Name.create("target.example.net.")), "target.example.net"],
        "NS" => [record(:NS, Resolv::DNS::Name.create("ns1.example.net.")), "ns1.example.net"],
        "MX" => [record(:MX, 10, Resolv::DNS::Name.create("mail.example.com.")), "10 mail.example.com"],
        "TXT" => [record(:TXT, "v=spf1 ", "-all"), "v=spf1 -all"],
        "SOA" => [record(:SOA, Resolv::DNS::Name.create("ns1.example.com."), Resolv::DNS::Name.create("admin.example.com."), 7, 3600, 600, 86_400, 300),
                  "ns1.example.com admin.example.com 7 3600 600 86400 300"],
        "CAA" => [record(:CAA, 0, "issue", "letsencrypt.org"), "0 issue letsencrypt.org"],
        "PTR" => [record(:PTR, Resolv::DNS::Name.create("dns.google.")), "dns.google"]
      }

      records.each do |type, (data, expected)|
        stub_udp(answers: [[60, data]])

        expect(query(type:).answers).to eq([expected]), type
      end
    end

    it "writes a null MX exchange as a dot" do
      stub_udp(answers: [[60, record(:MX, 0, Resolv::DNS::Name.create("."))]])

      expect(query(type: "MX").answers).to eq(["0 ."])
    end

    it "reports an alias when only a CNAME came back", :aggregate_failures do
      stub_udp(answers: [[60, record(:CNAME, Resolv::DNS::Name.create("target.example.net."))]])
      answer = query

      expect(answer.status).to eq(:cname)
      expect(answer.answers).to eq(["target.example.net"])
    end

    it "reports no data when the name exists without that record", :aggregate_failures do
      stub_udp
      answer = query

      expect(answer.status).to eq(:nodata)
      expect(answer.answers).to eq([])
      expect(answer.ttl).to be_nil
    end

    it "does not report an alias when the CNAME itself was asked for" do
      stub_udp
      expect(query(type: "CNAME").status).to eq(:nodata)
    end
  end

  describe "failures" do
    it "maps response codes to statuses", :aggregate_failures do
      { Resolv::DNS::RCode::NXDomain => :nxdomain, Resolv::DNS::RCode::ServFail => :servfail,
        Resolv::DNS::RCode::Refused => :refused, Resolv::DNS::RCode::FormErr => :error }.each do |rcode, status|
        stub_udp(rcode:)

        expect(query.status).to eq(status)
      end
    end

    it "reports a timeout", :aggregate_failures do
      allow(Network::Dns::Transport).to receive(:udp).and_raise(Network::Dns::Transport::TimedOut)
      answer = query

      expect(answer.status).to eq(:timeout)
      expect(answer.answers).to eq([])
    end

    it "reports transport errors" do
      allow(Network::Dns::Transport).to receive(:udp).and_raise(Network::Dns::Transport::Failed)

      expect(query.status).to eq(:error)
    end

    it "reports undecodable replies" do
      allow(Network::Dns::Transport).to receive(:udp).and_return("garbage")

      expect(query.status).to eq(:error)
    end

    it "rejects a reply to a different question" do
      stub_udp(id: 1, answers: [[60, record(:A, "93.184.216.34")]])
      allow(SecureRandom).to receive(:random_number).and_return(2)

      expect(query.status).to eq(:error)
    end
  end

  describe "truncated replies" do
    it "retries over TCP", :aggregate_failures do
      stub_udp(tc: 1)
      allow(Network::Dns::Transport).to receive(:tcp) { |payload:, **| reply_to(payload, answers: [[60, record(:A, "93.184.216.34")]]) }
      answer = query(timeout: 2)

      expect(answer.answers).to eq(["93.184.216.34"])
      expect(Network::Dns::Transport).to have_received(:tcp).with(hash_including(ip: "1.1.1.1", timeout: 2, port: 53))
    end
  end
end
