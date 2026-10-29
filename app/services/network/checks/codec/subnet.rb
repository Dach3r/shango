module Network
  module Checks
    module Codec
      module Subnet
        module_function

        def dump(data)
          data
        end

        def load(data)
          data.merge(scope: data[:scope].to_sym)
        end
      end
    end
  end
end
