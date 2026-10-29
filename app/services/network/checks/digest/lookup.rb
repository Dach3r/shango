module Network
  module Checks
    module Digest
      module Lookup
        module_function

        def call(data)
          tones = data[:findings].map { |finding| finding[:tone] }
          key, args = data[:domain] ? domain(data[:domain]) : address(data)
          Summary.new(label: data[:host], tone: tones.include?("bad") ? "bad" : (tones.include?("warn") ? "warn" : "ok"), key: "network.lookup.summary.#{key}", args:, progress: nil)
        end

        def domain(domain)
          registrar = domain.dig(:registrar, :name) || "—"
          return ["no_expiry", { registrar: }] unless domain[:expires]

          [domain[:days_left].negative? ? "expired" : "domain", { date: domain[:expires].first(10), registrar: }]
        end

        def address(data)
          asn = data[:asn].first
          name = asn&.dig(:name) || data.dig(:network, :name) || "—"
          asn ? ["ip", { asn: "AS#{asn[:number]}", name: }] : ["ip_no_asn", { name: }]
        end
      end
    end
  end
end
