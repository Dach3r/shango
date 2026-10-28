module Network
  module Checks
    module Digest
      module Dns
        module_function

        def call(data)
          summary = data[:summary]
          expected = data[:expected].present?
          reached = expected ? summary[:matched] : summary[:answered]
          settled = reached == summary[:total]
          progress = summary[:total].zero? ? 0 : (reached * 100.0 / summary[:total]).round
          Summary.new(label: "#{data[:host]} · #{data[:type]}", tone: settled ? "ok" : (reached.zero? ? "bad" : "warn"),
                      key: expected ? "network.dns.summary.expected" : "network.dns.summary.answered",
                      args: summary.slice(:matched, :answered, :total), progress:)
        end
      end
    end
  end
end
