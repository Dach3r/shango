# What happened to one request of a CollectionRun. The request may be deleted later, so its name is kept here.
class CollectionRunItem < ApplicationRecord
  include AASM

  belongs_to :collection_run, inverse_of: :items
  belongs_to :api_request, optional: true

  enum :status, { pending: "pending", running: "running", passed: "passed", failed: "failed", skipped: "skipped" }

  aasm column: :status, enum: true, create_scopes: false, no_direct_assignment: true, whiny_transitions: true do
    state :pending, initial: true
    state :running, :passed, :failed, :skipped

    event :start do
      transitions from: :pending, to: :running
    end

    event :mark_passed do
      transitions from: :running, to: :passed
    end

    event :mark_failed do
      transitions from: :running, to: :failed
    end

    event :mark_skipped do
      transitions from: %i[pending running], to: :skipped
    end
  end

  def failed_tests
    test_results.count { |outcome| outcome["status"] == "failed" }
  end

  def passed_tests
    test_results.count { |outcome| outcome["status"] == "passed" }
  end

  def error?
    error_kind.present?
  end
end
