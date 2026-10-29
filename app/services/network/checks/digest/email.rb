module Network
  module Checks
    module Digest
      module Email
        module_function

        def call(data)
          tones = data[:findings].map { |finding| finding[:tone] }
          bad = tones.count("bad")
          warnings = tones.count("warn")
          Summary.new(label: data[:host], tone: bad.positive? ? "bad" : (warnings.positive? ? "warn" : "ok"),
                      key: tones.empty? ? "network.email.summary.clean" : "network.email.summary.issues", args: { bad:, warn: warnings }, progress: nil)
        end
      end
    end
  end
end
