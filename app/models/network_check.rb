class NetworkCheck < ApplicationRecord
  KEEP_PER_KIND = 50
  INPUT_LIMIT = 255

  belongs_to :project
  belongs_to :user, optional: true
  belongs_to :environment, optional: true

  enum :kind, { dns: "dns", ports: "ports", ping: "ping", subnet: "subnet", tls: "tls", email: "email" }
  enum :outcome, { ok: "ok", warn: "warn", bad: "bad" }, prefix: :outcome

  validates :target, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def data
    Network::Checks::Codec.load(kind, result)
  end

  def digest
    Network::Checks::Digest.for(kind, data)
  end

  def previous
    project.network_checks.where(user_id:, kind:, target:).where(created_at: ...created_at).recent.first
  end
end
