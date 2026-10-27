# One saved run of a network tool (DNS, ports, TCP ping), shared by the members of its project. `input` is what was
# typed (`{{variables}}` unresolved), `result` the plain-JSON data of the run (see Network::Checks::Codec). Display text
# is derived at read time, never stored.
class NetworkCheck < ApplicationRecord
  KEEP_PER_KIND = 50
  INPUT_LIMIT = 255

  belongs_to :project
  belongs_to :user, optional: true
  belongs_to :environment, optional: true

  enum :kind, { dns: "dns", ports: "ports", ping: "ping" }
  enum :outcome, { ok: "ok", warn: "warn", bad: "bad" }, prefix: :outcome

  validates :target, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # What the result views read: the stored data turned back into the objects the run produced.
  def data
    Network::Checks::Codec.load(kind, result)
  end

  def digest
    Network::Checks::Digest.for(kind, data)
  end

  # The run before this one against the same target.
  def previous
    project.network_checks.where(kind:, target:).where(created_at: ...created_at).recent.first
  end
end
