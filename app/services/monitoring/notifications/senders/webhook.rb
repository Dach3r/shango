module Monitoring
  module Notifications
    module Senders
      # A signed JSON POST. The receiver checks `X-Shango-Signature`: `sha256=` and the hex HMAC-SHA256 of
      # "<X-Shango-Timestamp>.<body>" with the channel's signing secret.
      module Webhook
        module_function

        def call(message)
          body = message.payload.to_json
          timestamp = Time.current.to_i.to_s
          headers = { "X-Shango-Event" => message.event, "X-Shango-Timestamp" => timestamp, "X-Shango-Signature" => signature(message.channel.signing_secret, timestamp, body) }
          Post.call(uri: message.channel.uri, body:, headers:)
        end

        def signature(secret, timestamp, body)
          "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret.to_s, "#{timestamp}.#{body}")}"
        end
      end
    end
  end
end
