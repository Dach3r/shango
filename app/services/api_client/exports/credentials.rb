module ApiClient
  module Exports
    # What an export may carry of the saved secrets. Without `include`, secret auth fields and secret variable
    # values come out empty and OAuth tokens are left out; the shape stays so the importing app still knows the field.
    class Credentials
      def initialize(include:)
        @include = include
      end

      def auth_config(record)
        return {} unless Auth::Registry.keys.include?(record.auth_type)

        strategy = Auth::Registry.fetch(record.auth_type)
        config = record.auth_config.to_h.stringify_keys
        kept = config.slice(*strategy.field_names, *(strategy.managed_keys if @include))
        strategy.secret_field_names.each { |name| kept[name] = "" if kept.key?(name) && !@include }
        kept.transform_values(&:to_s)
      end

      def variable_value(variable)
        variable.secret && !@include ? "" : variable.value.to_s
      end
    end
  end
end
