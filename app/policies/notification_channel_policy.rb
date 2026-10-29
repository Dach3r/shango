class NotificationChannelPolicy < ApplicationPolicy
  def create?
    same_project?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def test?
    manage?
  end
end
