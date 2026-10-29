# What happened in a project: changes to its team (who did it to whom) and to its monitors and alert channels. Names
# are copied into `metadata` because the people, monitors and channels involved can be deleted while the history stays.
class AuditEvent < ApplicationRecord
  belongs_to :project
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :target, class_name: "User", optional: true

  enum :kind, {
    member_invited: "member_invited", invitation_accepted: "invitation_accepted", invitation_revoked: "invitation_revoked", role_changed: "role_changed",
    member_revoked: "member_revoked", member_left: "member_left", ownership_transferred: "ownership_transferred",
    monitor_created: "monitor_created", monitor_updated: "monitor_updated", monitor_deleted: "monitor_deleted", monitor_paused: "monitor_paused",
    monitor_resumed: "monitor_resumed", channel_created: "channel_created", channel_updated: "channel_updated", channel_deleted: "channel_deleted"
  }, validate: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def actor_name
    actor&.full_name || metadata["actor_name"]
  end

  def target_name
    target&.full_name || metadata["target_name"] || metadata["email"]
  end
end
