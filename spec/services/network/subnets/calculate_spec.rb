require "rails_helper"

RSpec.describe Network::Subnets::Calculate do
  def calculate(network, **options)
    described_class.call(network:, **options)
  end

  describe "IPv4" do
    it "describes a network written with a prefix", :aggregate_failures do
      result = calculate(" 192.168.1.10/24 ")

      expect(result).to be_success
      expect(result.data).to eq(
        family: 4, address: "192.168.1.10", cidr: "192.168.1.0/24", network: "192.168.1.0", prefix: 24, scope: :private, size: 256,
        netmask: "255.255.255.0", wildcard: "0.0.0.255", broadcast: "192.168.1.255", first: "192.168.1.1", last: "192.168.1.254", hosts: 254
      )
    end

    it "accepts a mask instead of a prefix" do
      expect(calculate("10.20.0.1 255.255.0.0").data).to include(cidr: "10.20.0.0/16", wildcard: "0.0.255.255", hosts: 65_534)
    end

    it "uses both addresses of a /31 and the only one of a /32", :aggregate_failures do
      expect(calculate("10.0.0.0/31").data).to include(first: "10.0.0.0", last: "10.0.0.1", hosts: 2, broadcast: nil)
      expect(calculate("8.8.8.8").data).to include(cidr: "8.8.8.8/32", first: "8.8.8.8", last: "8.8.8.8", hosts: 1, scope: :public)
    end

    it "names loopback and link-local ranges", :aggregate_failures do
      expect(calculate("127.0.0.0/8").data[:scope]).to eq(:loopback)
      expect(calculate("169.254.0.0/16").data[:scope]).to eq(:link_local)
    end
  end

  describe "IPv6" do
    it "describes the range without broadcast or mask", :aggregate_failures do
      data = calculate("2001:db8::1/48").data

      expect(data).to include(family: 6, cidr: "2001:db8::/48", first: "2001:db8::", last: "2001:db8:0:ffff:ffff:ffff:ffff:ffff", size: 2**80, hosts: 2**80)
      expect(data.keys).not_to include(:netmask, :wildcard, :broadcast)
    end

    it "names unique local and link-local ranges", :aggregate_failures do
      expect(calculate("fd00::/8").data[:scope]).to eq(:private)
      expect(calculate("fe80::/10").data[:scope]).to eq(:link_local)
    end
  end

  describe "split" do
    it "lists the subnets of the longer prefix", :aggregate_failures do
      expect(calculate("192.168.1.0/24", split: "/26").data[:split])
        .to eq(prefix: 26, count: 4, subnets: %w[192.168.1.0/26 192.168.1.64/26 192.168.1.128/26 192.168.1.192/26])
      expect(calculate("2001:db8::/32", split: "34").data[:split][:subnets]).to eq(%w[2001:db8::/34 2001:db8:4000::/34 2001:db8:8000::/34 2001:db8:c000::/34])
    end

    it "lists at most a page of subnets and keeps the full count", :aggregate_failures do
      split = calculate("10.0.0.0/8", split: "/24").data[:split]

      expect(split[:count]).to eq(65_536)
      expect(split[:subnets].size).to eq(described_class::MAX_SUBNETS)
      expect(split[:subnets].last).to eq("10.0.63.0/24")
    end

    it "refuses a prefix that is not longer or not a number", :aggregate_failures do
      ["/24", "/20", "/33", "abc", "2.5"].each do |split|
        result = calculate("192.168.1.0/24", split:)

        expect(result.error).to eq(:invalid_split), split
        expect(result.data).to eq(min: 25, max: 32)
      end
    end
  end

  describe "contains" do
    it "tells whether the address is inside", :aggregate_failures do
      expect(calculate("192.168.1.0/24", contains: "192.168.1.77").data[:contains]).to eq(address: "192.168.1.77", inside: true)
      expect(calculate("192.168.1.0/24", contains: "192.168.2.1").data[:contains][:inside]).to be(false)
      expect(calculate("192.168.1.0/24", contains: "::ffff:1").data[:contains][:inside]).to be(false)
    end

    it "refuses an invalid address", :aggregate_failures do
      result = calculate("192.168.1.0/24", contains: "nope")

      expect(result.error).to eq(:invalid_ip)
      expect(result.data).to eq(token: "nope")
    end
  end

  describe "invalid input" do
    it "asks for a network when it is blank" do
      expect(calculate(" ").error).to eq(:blank_network)
    end

    it "refuses what is not a network", :aggregate_failures do
      ["example.com", "10.0.0.0/33", "1.2.3.4/255.0.255.0", "10.0.0.0/24/8"].each do |network|
        result = calculate(network)

        expect(result.error).to eq(:invalid_network), network
        expect(result.data).to eq(token: network)
      end
    end
  end

  describe "variables" do
    let(:environment) { create(:environment) }

    it "resolves them in every field", :aggregate_failures do
      create(:variable, environment:, key: "vpc", value: "10.0.0.0/16")
      create(:variable, environment:, key: "size", value: "/17")
      create(:variable, environment:, key: "ip", value: "10.0.200.1")
      data = described_class.call(network: "{{vpc}}", split: "{{size}}", contains: "{{ip}}", environment:).data

      expect(data[:cidr]).to eq("10.0.0.0/16")
      expect(data[:split][:count]).to eq(2)
      expect(data[:contains][:inside]).to be(true)
    end

    it "names the variable that is not defined", :aggregate_failures do
      result = described_class.call(network: "10.0.0.0/16", contains: "{{nope}}", environment:)

      expect(result.error).to eq(:unresolved_variable)
      expect(result.data).to eq(name: "nope")
    end
  end
end
