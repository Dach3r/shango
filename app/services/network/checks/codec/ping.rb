module Network
  module Checks
    module Codec
      module Ping
        module_function

        def dump(data)
          data.slice(:host, :address, :port, :summary).merge(attempts: data[:attempts].map(&:to_h))
        end

        def load(data)
          data.merge(attempts: data[:attempts].map { |attempt| Tcp::Probe::Attempt.new(**attempt, status: attempt[:status].to_sym) })
        end
      end
    end
  end
end
