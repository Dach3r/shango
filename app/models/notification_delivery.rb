# One message to one channel: the opening or the resolution of an incident, or a test. At most one per channel,
# incident and event, so a retried job never alerts twice. `status` is an AASM state machine: `pending` until sent,
# or `failed` once the attempts run out or the failure cannot get better by retrying.
class NotificationDelivery < ApplicationRecord
  include AASM

  MAX_ATTEMPTS = 5

  belongs_to :notification_channel
  belongs_to :incident, optional: true

  enum :event, { incident_opened: "incident_opened", incident_resolved: "incident_resolved", test: "test" }, validate: true
  enum :status, { pending: "pending", sent: "sent", failed: "failed" }

  aasm column: :status, enum: true, create_scopes: false, no_direct_assignment: true, whiny_transitions: true do
    state :pending, initial: true
    state :sent, :failed

    event :deliver do
      transitions from: :pending, to: :sent, after: :stamp_sent
    end

    event :give_up do
      transitions from: :pending, to: :failed
    end
  end

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def finished?
    sent? || failed?
  end

  private

  def stamp_sent(at = Time.current)
    self.sent_at = at
  end
end
