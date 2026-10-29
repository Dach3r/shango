module Network
  module Lookups
    # What is known about a public IP address: the network it belongs to and who holds it (RDAP) and the autonomous
    # system that announces it (Cymru). The two are asked in parallel and either may be missing; the run only fails
    # when neither answered.
    class Address
      include Serviceable

      MAX_CIDRS = 10

      def initialize(ip:, host:, deadline:)
        @ip = ip
        @host = host
        @deadline = deadline
      end

      private

      def perform
        rdap, asn = Parallel.map([-> { network }, -> { Asn.call(ip: @ip) }], limit: 2, &:call)
        asns = asn.success? ? asn.record : []
        return Result.failure(error: rdap.error == :no_rdap_service ? :no_rdap_service : :rdap_unavailable) if rdap.failure? && asns.empty?

        findings = [
          ({ key: "rdap_failed", tone: "warn", args: {} } if rdap.failure?),
          ({ key: "asn_unavailable", tone: "warn", args: {} } if asn.failure?),
          ({ key: "not_announced", tone: "warn", args: {} } if asn.success? && asns.empty?)
        ].compact
        Result.success(nil, host: @host, type: "ip", domain: nil, network: (describe(rdap.record) if rdap.success?), asn: asns, findings:)
      end

      def network
        bootstrap = Rdap::Bootstrap.call(kind: @ip.ipv4? ? :ipv4 : :ipv6, key: @ip, deadline: @deadline)
        return bootstrap if bootstrap.failure?

        Rdap::Client.call(url: "#{bootstrap.record}ip/#{@ip}", deadline: @deadline)
      end

      def describe(json)
        events = Array(json["events"]).grep(Hash).to_h { |event| [event["eventAction"], Clean.time(event["eventDate"])] }
        {
          name: Clean.text(json["name"]), handle: Clean.text(json["handle"]), type: Clean.text(json["type"]), country: Clean.text(json["country"]),
          range: ([json["startAddress"], json["endAddress"]].map { |address| Clean.text(address) }.join(" - ") if json["startAddress"] && json["endAddress"]),
          cidrs: Array(json["cidr0_cidrs"]).grep(Hash).filter_map { |cidr| "#{Clean.text(cidr["v4prefix"] || cidr["v6prefix"])}/#{cidr["length"].to_i}" if cidr["v4prefix"] || cidr["v6prefix"] }.first(MAX_CIDRS),
          organization: Entities.organization(json["entities"]), abuse: Entities.abuse(json["entities"]), updated: events["last changed"]
        }
      end
    end
  end
end
