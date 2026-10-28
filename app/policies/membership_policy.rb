class MembershipPolicy < ApplicationPolicy
  # Preferences (click modes, theme) belong to the member that owns the membership.
  def update?
    record.id == membership.id
  end
end
