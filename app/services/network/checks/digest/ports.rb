module Network
  module Checks
    module Digest
      module Ports
        module_function

        def call(data)
          counts = data[:counts]
          Summary.new(label: data[:host], tone: counts[:open].positive? ? "ok" : "warn", key: "network.ports.summary",
                      args: counts.slice(:open, :closed, :filtered), progress: nil)
        end
      end
    end
  end
end
