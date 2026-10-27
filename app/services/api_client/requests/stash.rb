module ApiClient
  module Requests
    # Unsaved editor state of a request, per user, kept in the cache (never the database) so it survives switching tabs.
    # Encrypted because headers and body may carry credentials; secret auth fields are not kept at all.
    module Stash
      TTL = 24.hours
      MAX_BYTES = 1.megabyte

      class << self
        # Returns false when the state is too large to keep.
        def write(api_request:, user:, attributes:)
          payload = encryptor.encrypt_and_sign(sanitize(attributes).to_json)
          return false if payload.bytesize > MAX_BYTES

          Rails.cache.write(key(api_request.id, user.id), payload, expires_in: TTL)
        end

        def read(api_request:, user:)
          payload = Rails.cache.read(key(api_request.id, user.id))
          JSON.parse(encryptor.decrypt_and_verify(payload)) if payload
        rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError
          nil
        end

        def clear(api_request:, user:)
          Rails.cache.delete(key(api_request.id, user.id))
        end

        # Ids of the given requests that have unsaved state for the user.
        def ids(requests:, user:)
          keys = requests.to_h { |api_request| [key(api_request.id, user.id), api_request.id] }
          Rails.cache.read_multi(*keys.keys).keys.map { |key| keys[key] }
        end

        private

        def sanitize(attributes)
          data = attributes.to_h.deep_stringify_keys
          data["auth_config"] = data["auth_config"].to_h.except(*secret_fields(data["auth_type"]))
          data
        end

        def secret_fields(auth_type)
          return [] unless Auth::Registry.keys.include?(auth_type)

          Auth::Registry.fetch(auth_type).fields.select(&:secret).map { |field| field.name.to_s }
        end

        def key(api_request_id, user_id)
          "api_client/request_stash/#{user_id}/#{api_request_id}"
        end

        def encryptor
          @encryptor ||= ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("request stash", ActiveSupport::MessageEncryptor.key_len), serializer: JSON)
        end
      end
    end
  end
end
