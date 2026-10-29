module Network
  module Checks
    # Data of a run <-> plain JSON for `NetworkCheck#result`, one codec per kind (`dump(data)` and `load(data)`).
    module Codec
      MAX_ANSWERS = 10
      MAX_ANSWER_LENGTH = 255

      KINDS = { "dns" => Dns, "ports" => Ports, "ping" => Ping, "subnet" => Subnet, "tls" => Tls, "email" => Email }.freeze

      module_function

      def dump(kind, data)
        KINDS.fetch(kind.to_s).dump(data).as_json
      end

      def load(kind, stored)
        KINDS.fetch(kind.to_s).load(stored.deep_symbolize_keys)
      end
    end
  end
end
