module Network
  module Checks
    module Digest
      module Tls
        module_function

        def call(data)
          certificate = data[:certificate]
          tones = data[:findings].map { |finding| finding[:tone] }
          date = certificate[:validity] == "not_yet_valid" ? certificate[:not_before] : certificate[:not_after]
          Summary.new(label: "#{data[:host]}:#{data[:port]}", tone: tones.include?("bad") ? "bad" : (tones.include?("warn") ? "warn" : "ok"),
                      key: "network.tls.summary.#{certificate[:validity] == "expiring" ? "valid" : certificate[:validity]}",
                      args: { date: date.first(10), version: data[:session][:version] }, progress: nil)
        end
      end
    end
  end
end
