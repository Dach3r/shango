module AuditEventsHelper
  # One readable line for an event: "<actor> removed <target>", with the people's names or what is left of them.
  def audit_event_summary(event)
    gone = t("projects.audit_events.index.someone")
    t("projects.audit_events.index.kinds.#{event.kind}",
      actor: event.actor_name || gone, target: event.target_name || gone, email: event.metadata["email"], name: event.metadata["name"],
      role: role_label(event.metadata["role"]), from: role_label(event.metadata["from"]), to: role_label(event.metadata["to"]))
  end

  private

  def role_label(role)
    role.present? ? t("projects.members.index.roles.#{role}") : ""
  end
end
