class AddMonitoringKindsToAuditEvents < ActiveRecord::Migration[8.1]
  TEAM = "'member_invited', 'invitation_accepted', 'invitation_revoked', 'role_changed', 'member_revoked', 'member_left', 'ownership_transferred'".freeze
  MONITORING = "'monitor_created', 'monitor_updated', 'monitor_deleted', 'monitor_paused', 'monitor_resumed', 'channel_created', 'channel_updated', 'channel_deleted'".freeze

  def change
    remove_check_constraint :audit_events, "kind IN (#{TEAM})", name: "audit_events_kind_check"
    add_check_constraint :audit_events, "kind IN (#{TEAM}, #{MONITORING})", name: "audit_events_kind_check"
  end
end
