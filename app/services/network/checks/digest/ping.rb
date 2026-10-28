module Network
  module Checks
    module Digest
      module Ping
        module_function

        def call(data)
          summary = data[:summary]
          Summary.new(label: "#{data[:host]}:#{data[:port]}", tone: summary[:received] == summary[:sent] ? "ok" : (summary[:received].zero? ? "bad" : "warn"),
                      key: "network.ping.summary", args: summary.slice(:received, :sent, :loss), progress: nil)
        end
      end
    end
  end
end
