module Monitoring
  module Notifications
    module Senders
      # A message to a Discord webhook: the alert line and a link to the monitor, with mentions turned off so a monitor
      # name such as "@everyone" pings nobody. Discord answers a burst with 429 and `Retry-After`, which the delivery
      # job honours.
      module Discord
        MAX_LENGTH = 2000

        module_function

        def call(message)
          content = "#{message.text}\n#{message.url}".first(MAX_LENGTH)
          Post.call(uri: message.channel.uri, body: { content:, allowed_mentions: { parse: [] } }.to_json)
        end
      end
    end
  end
end
