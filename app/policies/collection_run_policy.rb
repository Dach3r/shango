# Anyone in the project may see a run and start one of a collection they can open; stopping it is for who started it or an owner.
class CollectionRunPolicy < ApplicationPolicy
  def show?
    same_project?
  end

  def create?
    same_project?
  end

  def cancel?
    same_project? && record.active? && (owner? || record.user_id == membership.user_id)
  end
end
