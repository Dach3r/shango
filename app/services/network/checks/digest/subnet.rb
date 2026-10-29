module Network
  module Checks
    module Digest
      module Subnet
        module_function

        def call(data)
          outside = data[:contains] && !data[:contains][:inside]
          Summary.new(label: data[:cidr], tone: outside ? "warn" : "ok", key: "network.subnet.summary",
                      args: { hosts: count(data[:hosts]), version: data[:family] }, progress: nil)
        end

        def count(number)
          number < 2**53 ? ActiveSupport::NumberHelper.number_to_delimited(number) : "2^#{number.bit_length - 1}"
        end
      end
    end
  end
end
