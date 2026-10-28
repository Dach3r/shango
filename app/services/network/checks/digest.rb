module Network
  module Checks
    # The label, tone and one-line summary of a run, derived at read time; one digest per kind (`call(data)`).
    module Digest
      Summary = Data.define(:label, :tone, :key, :args, :progress)

      KINDS = { "dns" => Dns, "ports" => Ports, "ping" => Ping }.freeze

      module_function

      def for(kind, data)
        KINDS.fetch(kind.to_s).call(data)
      end
    end
  end
end
