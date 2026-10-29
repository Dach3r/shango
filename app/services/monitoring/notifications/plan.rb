module Monitoring
  module Notifications
    # The alerts of an incident event: one pending delivery per enabled channel of the incident's monitor, created in
    # the caller's transaction and enqueued after it commits, so a check never waits for a delivery.
    module Plan
      module_function

      def call(incident, event)
        incident.uptime_monitor.notification_channels.where(enabled: true).map do |channel|
          channel.deliveries.create!(incident:, event:)
        end
      end

      def enqueue(deliveries)
        ActiveJob.perform_all_later(deliveries.map { |delivery| NotificationDeliveryJob.new(delivery.id) }) if deliveries.any?
      end
    end
  end
end
