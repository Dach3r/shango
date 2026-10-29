module Monitoring
  module Notifications
    module Senders
      # A message to a Slack incoming webhook: the alert line and a link to the monitor. `&`, `<` and `>` are escaped so
      # a monitor name cannot inject links or mentions.
      module Slack
        module_function

        def call(message)
          text = "#{escape(message.text)}\n<#{message.url}|#{escape(I18n.t("monitoring.notifications.open", locale: message.locale))}>"
          Post.call(uri: message.channel.uri, body: { text: }.to_json)
        end

        def escape(text)
          text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
        end
      end
    end
  end
end
