module Network
  module Checks
    module Codec
      MAX_ANSWERS = 10
      MAX_ANSWER_LENGTH = 255

      module_function

      def dump(kind, data)
        case kind.to_s
        when "dns" then data.slice(:host, :type, :expected, :summary).merge(rows: data[:rows].map { |row| dump_dns_row(row) })
        when "ports" then data.slice(:host, :address, :counts).merge(rows: data[:rows].map(&:to_h))
        else data.slice(:host, :address, :port, :summary).merge(attempts: data[:attempts].map(&:to_h))
        end.as_json
      end

      def load(kind, stored)
        data = stored.deep_symbolize_keys
        case kind.to_s
        when "dns" then data.merge(rows: data[:rows].map { |row| load_dns_row(row) })
        when "ports" then data.merge(rows: data[:rows].map { |row| PortChecks::Row.new(**row, status: row[:status].to_sym) })
        else data.merge(attempts: data[:attempts].map { |attempt| Tcp::Probe::Attempt.new(**attempt, status: attempt[:status].to_sym) })
        end
      end

      def dump_dns_row(row)
        row.to_h.merge(answers: row.answers.first(MAX_ANSWERS).map { |answer| answer.to_s.truncate(MAX_ANSWER_LENGTH) })
      end

      def load_dns_row(row)
        Dns::Row.new(**row, group: row[:group].to_sym, status: row[:status].to_sym, match: row[:match]&.to_sym)
      end
    end
  end
end
