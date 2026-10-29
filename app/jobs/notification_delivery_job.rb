# Sends one alert of a monitor (or a test) and schedules its own retry while the delivery has attempts left.
class NotificationDeliveryJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(delivery_id) { delivery_id }, duration: 1.minute, on_conflict: :discard

  def perform(delivery_id)
    delivery = NotificationDelivery.find_by(id: delivery_id)
    return unless delivery

    result = Monitoring::Notifications::Deliver.call(delivery:)
    self.class.set(wait: result.data[:retry_in].seconds).perform_later(delivery_id) if result.data[:retry_in]
  end
end
