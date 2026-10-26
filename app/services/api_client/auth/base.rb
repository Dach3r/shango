module ApiClient
  module Auth
    # A strategy turns saved credentials into request headers/query/signature.
    # To add one: subclass Base, declare `field`s (they drive the form), implement `apply`,
    # and list the class in Registry::STRATEGIES.
    class Base
      Field = Struct.new(:name, :type, :secret, :required, :options, :default, :placeholder, :show_when, keyword_init: true)

      class << self
        def key
          name.demodulize.underscore
        end

        def fields
          @fields ||= []
        end

        # `show_when` ({ other_field: [values] }) hides the field in the form unless that field has one of the values.
        def field(name, type: :text, secret: false, required: false, options: nil, default: nil, placeholder: nil, show_when: nil)
          fields << Field.new(name: name.to_s, type:, secret:, required:, options:, default:, placeholder:, show_when:)
        end

        def field_names
          fields.map(&:name)
        end

        def secret_field_names
          fields.select(&:secret).map(&:name)
        end

        # Keys kept in the saved config that are not form fields (e.g. OAuth tokens).
        def managed_keys
          []
        end
      end

      attr_reader :config, :owner

      # `config` has its variables already resolved; `owner` is the record that stores the credentials.
      def initialize(config, owner: nil, dry_run: false)
        @config = config.to_h.stringify_keys
        @owner = owner
        @dry_run = dry_run
      end

      def apply(_request)
        raise NotImplementedError, "#{self.class} must implement #apply"
      end

      # Strategies that answer a 401 challenge (Digest) return the headers to retry with, otherwise nil.
      def respond_to_challenge(_response, _request)
        nil
      end

      # Values that must never be stored or shown.
      def secrets
        self.class.secret_field_names.filter_map { |name| config[name].presence } + managed_secrets
      end

      private

      def dry_run?
        @dry_run
      end

      def managed_secrets
        []
      end

      def require_config!(*names)
        missing = names.select { |name| config[name].blank? }
        raise ConfigurationError, "Missing #{missing.join(", ")}" if missing.any?
      end
    end
  end
end
