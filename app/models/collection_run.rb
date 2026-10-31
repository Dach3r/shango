# A run of a collection (or one folder of it): its requests are sent one after another, each checked against its assertions,
# and one CollectionRunItem per request keeps the outcome (see ApiClient::Runs::Perform). Nothing in a run is an editing session:
# it never touches the request history or the latest responses.
class CollectionRun < ApplicationRecord
  include AASM

  DEFAULT_MAX_REQUESTS = 200
  DEFAULT_RETENTION_DAYS = 30
  KEEP_PER_COLLECTION = 20
  MAX_DELAY_MS = 10_000

  belongs_to :project
  belongs_to :collection
  belongs_to :folder, optional: true
  belongs_to :user
  belongs_to :environment, optional: true

  has_many :items, -> { order(:position) }, class_name: "CollectionRunItem", dependent: :delete_all, inverse_of: :collection_run

  enum :status, { queued: "queued", running: "running", completed: "completed", failed: "failed", cancelled: "cancelled" }

  aasm column: :status, enum: true, create_scopes: false, no_direct_assignment: true, whiny_transitions: true do
    state :queued, initial: true
    state :running, :completed, :failed, :cancelled

    event :start do
      transitions from: :queued, to: :running, after: :stamp_start
    end

    event :finish do
      transitions from: :running, to: :completed, after: :stamp_finish
    end

    event :break_down do
      transitions from: %i[queued running], to: :failed, after: :stamp_finish
    end

    event :cancel do
      transitions from: %i[queued running], to: :cancelled, after: :stamp_finish
    end
  end

  scope :active, -> { where(status: %w[queued running]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :finished_before, ->(time) { where(status: %w[completed failed cancelled], finished_at: ...time) }

  def self.max_requests
    ENV.fetch("SHANGO_RUN_MAX_REQUESTS", DEFAULT_MAX_REQUESTS).to_i.clamp(1, 1_000)
  end

  def self.retention_days
    ENV.fetch("SHANGO_RUN_RETENTION_DAYS", DEFAULT_RETENTION_DAYS).to_i
  end

  def finished?
    completed? || failed? || cancelled?
  end

  def active?
    queued? || running?
  end

  def successful?
    completed? && failed_count.zero?
  end

  def option(name)
    options.fetch(name.to_s)
  end

  def duration
    return unless started_at

    ((finished_at || Time.current) - started_at).clamp(0, nil)
  end

  def scope_name
    folder&.name || collection.name
  end

  private

  def stamp_start
    self.started_at = Time.current
  end

  def stamp_finish
    self.finished_at = Time.current
  end
end
