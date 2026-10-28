# What happened to a project's team: who did it to whom. Names are copied into `metadata` because the people involved
# can delete their accounts while the history stays.
class AuditEvent < ApplicationRecord
  belongs_to :project
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :target, class_name: "User", optional: true

  enum :kind, {
    member_invited: "member_invited", invitation_accepted: "invitation_accepted", invitation_revoked: "invitation_revoked", role_changed: "role_changed",
    member_revoked: "member_revoked", member_left: "member_left", ownership_transferred: "ownership_transferred"
  }, validate: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def actor_name
    actor&.full_name || metadata["actor_name"]
  end

  def target_name
    target&.full_name || metadata["target_name"] || metadata["email"]
  end
end
