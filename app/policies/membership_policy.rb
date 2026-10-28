class MembershipPolicy < ApplicationPolicy
  # Preferences (click modes, theme) belong to the member that owns the membership.
  def update?
    record.id == membership.id
  end

  # Owners manage the roles of the project's members.
  def change_role?
    owner? && same_project?
  end

  # Owners remove other members; leaving yourself goes through `leave?`.
  def revoke?
    change_role? && record.id != membership.id
  end

  def leave?
    update?
  end
end
