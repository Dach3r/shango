module Network
  module Checks
    module Codec
      module Dns
        module_function

        def dump(data)
          data.slice(:host, :type, :expected, :summary, :reverse, :forward).merge(rows: data[:rows].map { |row| dump_row(row) })
        end

        def load(data)
          data.merge(rows: data[:rows].map { |row| load_row(row) })
        end

        def dump_row(row)
          row.to_h.merge(answers: row.answers.first(MAX_ANSWERS).map { |answer| answer.to_s.truncate(MAX_ANSWER_LENGTH) })
        end

        def load_row(row)
          Network::Dns::Row.new(**row, group: row[:group].to_sym, status: row[:status].to_sym, match: row[:match]&.to_sym)
        end
      end
    end
  end
end
