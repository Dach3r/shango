require "rails_helper"

RSpec.describe Network::SsrfPolicy do
  def addrinfo(*addresses)
    addresses.map { |address| instance_double(Addrinfo, ip_address: address) }
  end

  describe ".enabled?" do
    it "is off by default outside production" do
      expect(described_class.enabled?).to be(false)
    end

    it "is on by default in production" do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(described_class.enabled?).to be(true)
    end

    it "can be turned off explicitly in production" do
      allow(Rails.env).to receive(:production?).and_return(true)
      stub_const("ENV", ENV.to_h.merge("SHANGO_BLOCK_PRIVATE_NETWORKS" => "false"))

      expect(described_class.enabled?).to be(false)
    end

    it "is on when the env var is true" do
      stub_const("ENV", ENV.to_h.merge("SHANGO_BLOCK_PRIVATE_NETWORKS" => "true"))

      expect(described_class.enabled?).to be(true)
    end
  end

  describe ".check!" do
    context "when disabled" do
      it "returns nil" do
        expect(described_class.check!("localhost")).to be_nil
      end
    end

    context "when enabled" do
      before { stub_const("ENV", ENV.to_h.merge("SHANGO_BLOCK_PRIVATE_NETWORKS" => "true")) }

      it "returns the first public address" do
        allow(Addrinfo).to receive(:getaddrinfo).and_return(addrinfo("93.184.216.34", "93.184.216.34", "2606:2800:220:1::1"))

        expect(described_class.check!("example.com")).to eq("93.184.216.34")
      end

      it "blocks private addresses" do
        allow(Addrinfo).to receive(:getaddrinfo).and_return(addrinfo("93.184.216.34", "10.0.0.1"))

        expect { described_class.check!("evil.test") }.to raise_error(described_class::Blocked, /evil.test resolves to a private address \(10.0.0.1\)/)
      end

      it "blocks a host when any of its addresses is private, wherever it is listed" do
        allow(Addrinfo).to receive(:getaddrinfo).and_return(addrinfo("10.0.0.1", "93.184.216.34"))

        expect { described_class.check!("rebind.test") }.to raise_error(described_class::Blocked)
      end

      it "blocks literal and obfuscated loopback hosts", :aggregate_failures do
        ["127.0.0.1", "127.1", "2130706433", "0x7f000001", "0", "0.0.0.0", "::1", "localhost", "169.254.169.254"].each do |host|
          expect { described_class.check!(host) }.to raise_error(described_class::Blocked), host
        end
      end

      it "does not block a public literal address" do
        expect(described_class.check!("93.184.216.34")).to eq("93.184.216.34")
      end

      it "lets resolution errors through" do
        allow(Addrinfo).to receive(:getaddrinfo).and_raise(SocketError, "nope")

        expect { described_class.check!("nope.test") }.to raise_error(SocketError)
      end
    end
  end

  describe ".blocked?" do
    it "flags private, loopback and mapped addresses", :aggregate_failures do
      expect(described_class.blocked?("192.168.1.1")).to be(true)
      expect(described_class.blocked?("::1")).to be(true)
      expect(described_class.blocked?("::ffff:127.0.0.1")).to be(true)
      expect(described_class.blocked?("169.254.169.254")).to be(true)
      expect(described_class.blocked?("64:ff9b::a00:1")).to be(true)
      expect(described_class.blocked?("2002:c0a8:101::1")).to be(true)
    end

    it "flags the remaining reserved ranges", :aggregate_failures do
      %w[0.0.0.0 0.1.2.3 10.255.255.255 100.64.0.1 172.16.0.1 172.31.255.255 192.0.0.1 198.18.0.1 224.0.0.1 240.0.0.1 255.255.255.255 ::
         fc00::1 fd12:3456::1 fe80::1 ff02::1 ::ffff:10.0.0.1 ::ffff:a9fe:a9fe].each do |address|
        expect(described_class.blocked?(address)).to be(true), address
      end
    end

    it "does not flag addresses just outside the private ranges", :aggregate_failures do
      %w[172.15.255.255 172.32.0.1 100.63.255.255 100.128.0.1 11.0.0.1 192.169.0.1 223.255.255.255 ::ffff:8.8.8.8].each do |address|
        expect(described_class.blocked?(address)).to be(false), address
      end
    end

    it "does not mix address families" do
      expect(described_class.blocked?("2606:4700::1111")).to be(false)
    end

    it "allows public addresses", :aggregate_failures do
      expect(described_class.blocked?("8.8.8.8")).to be(false)
      expect(described_class.blocked?("2606:4700::1111")).to be(false)
    end
  end
end
