module Network
  module Checks
    module Codec
      module Ports
        module_function

        def dump(data)
          data.slice(:host, :address, :counts).merge(rows: data[:rows].map(&:to_h))
        end

        def load(data)
          data.merge(rows: data[:rows].map { |row| PortChecks::Row.new(**row, status: row[:status].to_sym) })
        end
      end
    end
  end
end
