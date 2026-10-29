class UptimeMonitorPolicy < ApplicationPolicy
  def show?
    same_project?
  end

  def create?
    same_project?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def run?
    manage?
  end

  def pause?
    manage?
  end
end
