module Monitoring
  module Channels
    # Sends a test message to a channel, through the same delivery path as the alerts.
    class SendTest
      include Serviceable

      def initialize(channel:)
        @channel = channel
      end

      private

      def perform
        delivery = @channel.deliveries.create!(event: "test")
        NotificationDeliveryJob.perform_later(delivery.id)
        Result.success(delivery)
      end
    end
  end
end
