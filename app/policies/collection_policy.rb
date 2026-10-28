class CollectionPolicy < ApplicationPolicy
  def show?
    same_project?
  end

  def create?
    same_project?
  end

  def export?
    same_project?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end
end
