module Monitoring
  module Notifications
    # What a delivery says, in its channel's language: the monitor, a safe description of its target (the URL as typed,
    # never with its variables resolved), the cause, the times and a link. A test message names the channel only.
    class Message
      attr_reader :delivery, :channel, :incident, :monitor

      def initialize(delivery)
        @delivery = delivery
        @channel = delivery.notification_channel
        @incident = delivery.incident
        @monitor = incident&.uptime_monitor
      end

      def event
        delivery.event
      end

      def test?
        delivery.test?
      end

      def locale
        channel.locale
      end

      def subject
        translate("subjects.#{event}", monitor: monitor&.name, channel: channel.name, project: channel.project.name)
      end

      # One line for chat channels.
      def text
        translate("text.#{event}", monitor: monitor&.name, channel: channel.name, cause: cause, duration: duration, project: channel.project.name)
      end

      def cause
        return unless incident

        text = translate("causes.#{incident.cause}", default: incident.cause)
        incident.detail.present? ? "#{text} (#{incident.detail})" : text
      end

      def duration
        return unless incident&.resolved_at

        I18n.with_locale(locale) { ApplicationController.helpers.distance_of_time_in_words(incident.started_at, incident.resolved_at) }
      end

      def target
        return unless monitor

        case monitor.kind
        when "http" then monitor.mode == "request" ? request_name : monitor.url
        when "tcp", "ssl" then "#{monitor.host}:#{monitor.port}"
        when "domain" then monitor.host
        end
      end

      def kind_name
        translate("kinds.#{monitor.kind}") if monitor
      end

      def url
        options = Rails.application.config.action_mailer.default_url_options || {}
        routes = Rails.application.routes.url_helpers
        monitor ? routes.monitoring_monitor_url(monitor, **options) : routes.monitoring_channels_url(**options)
      end

      def payload
        {
          event:, text:, sent_at: Time.current.iso8601, url:,
          project: { id: channel.project_id, name: channel.project.name },
          monitor: monitor && { id: monitor.id, name: monitor.name, kind: monitor.kind, target: },
          incident: incident && {
            id: incident.id, cause: incident.cause, cause_text: cause, detail: incident.detail, started_at: incident.started_at.iso8601,
            resolved_at: incident.resolved_at&.iso8601, duration_seconds: incident.resolved_at && (incident.resolved_at - incident.started_at).round
          }
        }
      end

      private

      def request_name
        request = monitor.api_request
        request && [request.collection.name, request.name].join(" / ")
      end

      def translate(key, **)
        I18n.t("monitoring.#{key.start_with?("causes", "kinds") ? key : "notifications.#{key}"}", locale:, **)
      end
    end
  end
end
