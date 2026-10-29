module Monitoring
  module Notifications
    # Sends one delivery with the sender of its channel's kind. A failure is recorded on the delivery and, while
    # attempts remain and retrying can help, returns `retry_in`; otherwise the delivery is given up. A delivery that
    # already finished is never sent again.
    class Deliver
      include Serviceable

      SENDERS = { "email" => Senders::Email, "webhook" => Senders::Webhook, "slack" => Senders::Slack, "discord" => Senders::Discord }.freeze
      WAITS = [10, 30, 120, 600].freeze
      MAX_WAIT = 3600

      def initialize(delivery:, at: Time.current)
        @delivery = delivery
        @at = at
      end

      private

      def perform
        return Result.success(@delivery) if @delivery.finished?

        @delivery.increment(:attempts)
        result = SENDERS.fetch(@delivery.notification_channel.kind).call(Message.new(@delivery))
        return sent if result.success?

        failed(result)
      end

      def sent
        @delivery.error = @delivery.detail = nil
        @delivery.deliver!(@at)
        Result.success(@delivery)
      end

      def failed(result)
        @delivery.assign_attributes(error: result.error.to_s, detail: result.data[:detail]&.first(255))
        if result.data[:permanent] || @delivery.attempts >= NotificationDelivery::MAX_ATTEMPTS
          @delivery.give_up!
          return Result.failure(@delivery, error: result.error)
        end

        @delivery.save!
        wait = [WAITS.fetch(@delivery.attempts - 1), result.data[:retry_after].to_i].max.clamp(..MAX_WAIT)
        Result.failure(@delivery, error: result.error, retry_in: wait)
      end
    end
  end
end
