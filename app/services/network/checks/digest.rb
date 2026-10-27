module Network
  module Checks
    # What a run boils down to, for the history list and the result header: a label, a tone (`ok`, `warn`, `bad`), the
    # i18n key and arguments of its one-line summary, and for DNS how far the change has spread (0..100).
    module Digest
      Summary = Data.define(:label, :tone, :key, :args, :progress)

      module_function

      def for(kind, data)
        case kind.to_s
        when "dns" then dns(data)
        when "ports" then ports(data)
        else ping(data)
        end
      end

      def dns(data)
        summary = data[:summary]
        expected = data[:expected].present?
        reached = expected ? summary[:matched] : summary[:answered]
        settled = reached == summary[:total] && (expected || summary[:agree])
        progress = summary[:total].zero? ? 0 : (reached * 100.0 / summary[:total]).round
        Summary.new(label: "#{data[:host]} · #{data[:type]}", tone: settled ? "ok" : (reached.zero? ? "bad" : "warn"),
                    key: expected ? "network.dns.summary.expected" : "network.dns.summary.answered",
                    args: summary.slice(:matched, :answered, :total), progress:)
      end

      def ports(data)
        counts = data[:counts]
        Summary.new(label: data[:host], tone: counts[:open].positive? ? "ok" : "warn", key: "network.ports.summary",
                    args: counts.slice(:open, :closed, :filtered), progress: nil)
      end

      def ping(data)
        summary = data[:summary]
        Summary.new(label: "#{data[:host]}:#{data[:port]}", tone: summary[:received] == summary[:sent] ? "ok" : (summary[:received].zero? ? "bad" : "warn"),
                    key: "network.ping.summary", args: summary.slice(:received, :sent, :loss), progress: nil)
      end
    end
  end
end
