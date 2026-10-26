module ApiClient
  module Auth
    # Applies submitted auth settings to a collection, folder or request: keeps only the fields of the
    # chosen strategy, keeps stored secrets when their input is left blank, and keeps OAuth tokens.
    class Assign
      include Serviceable

      def initialize(record:, auth_type:, auth_config:)
        @record = record
        @auth_type = auth_type.presence || record.auth_type
        @auth_config = auth_config.respond_to?(:to_unsafe_h) ? auth_config.to_unsafe_h : auth_config.to_h
      end

      private

      def perform
        @record.auth_type = @auth_type
        @record.auth_config = build_config
        @record
      end

      def build_config
        return {} unless Registry.keys.include?(@auth_type)

        strategy = Registry.fetch(@auth_type)
        existing = @record.auth_type_was == @auth_type ? @record.auth_config_was.to_h : {}
        incoming = @auth_config.stringify_keys

        config = strategy.fields.each_with_object({}) do |field, result|
          value = incoming[field.name].presence
          value ||= existing[field.name].presence if field.secret
          result[field.name] = value.to_s if value
        end

        config.merge(existing.slice(*strategy.managed_keys))
      end
    end
  end
end
