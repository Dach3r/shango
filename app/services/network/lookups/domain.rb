module Network
  module Lookups
    # Registration data of a domain from RDAP: registrar, dates, status, nameservers and DNSSEC. The name typed may be
    # a subdomain, so the registered domain is found by dropping labels from the left until the registry knows it.
    class Domain
      include Serviceable

      MAX_CANDIDATES = 3
      EXPIRING_DAYS = 30
      MAX_LISTED = 20
      HOLDS = %w[clienthold serverhold].freeze
      PENDING = %w[pendingdelete redemptionperiod].freeze

      def initialize(host:, deadline:)
        @host = host
        @deadline = deadline
      end

      private

      def perform
        labels = @host.split(".")
        bootstrap = Rdap::Bootstrap.call(kind: :dns, key: labels.last, deadline: @deadline)
        return bootstrap if bootstrap.failure?

        Array.new([[labels.size - 1, 1].max, MAX_CANDIDATES].min) { |index| labels[index..].join(".") }.each do |name|
          response = Rdap::Client.call(url: "#{bootstrap.record}domain/#{name}", deadline: @deadline)
          next if response.failure? && response.error == :not_found
          return Result.failure(error: :rdap_unavailable) if response.failure?

          domain = describe(response.record, name)
          return Result.success(nil, host: @host, type: "domain", domain:, network: nil, asn: [], findings: findings(domain))
        end
        Result.failure(error: :not_registered)
      end

      def describe(json, queried)
        events = Array(json["events"]).grep(Hash).to_h { |event| [event["eventAction"], Clean.time(event["eventDate"])] }
        expires = events["expiration"]
        signed = json["secureDNS"]["delegationSigned"] if json["secureDNS"].is_a?(Hash)
        {
          name: Clean.text(json["ldhName"])&.downcase || queried, queried:, registrar: Entities.registrar(json["entities"]), abuse: Entities.abuse(json["entities"]),
          registered: events["registration"], expires:, updated: events["last changed"], days_left: (((Time.zone.parse(expires) - Time.current) / 1.day).floor if expires),
          statuses: Array(json["status"]).filter_map { |status| Clean.text(status) }.first(MAX_LISTED),
          nameservers: Array(json["nameservers"]).grep(Hash).filter_map { |server| Clean.text(server["ldhName"])&.downcase }.first(MAX_LISTED),
          dnssec: ([true, false].include?(signed) ? signed : nil)
        }
      end

      def findings(domain)
        flags = domain[:statuses].map { |status| status.downcase.delete(" ") }
        days = domain[:days_left]
        [
          *expiry(domain, days),
          ({ key: "hold", tone: "bad", args: {} } if flags.intersect?(HOLDS)),
          ({ key: "pending_delete", tone: "bad", args: {} } if flags.intersect?(PENDING))
        ].compact
      end

      def expiry(domain, days)
        return [] unless days

        date = domain[:expires].first(10)
        return [{ key: "expired", tone: "bad", args: { date: } }] if days.negative?

        days <= EXPIRING_DAYS ? [{ key: "expiring", tone: "warn", args: { date: } }] : []
      end
    end
  end
end
