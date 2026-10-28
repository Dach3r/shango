# Requests in a collection follow it, so managing them takes managing the collection. A request that is not saved yet is a draft that belongs to one user.
class ApiRequestPolicy < ApplicationPolicy
  def show?
    same_project? && (!record.draft? || own_draft?)
  end

  # Sending is read-level: any member can run any visible request.
  def execute?
    show?
  end

  def create?
    return same_project? && own_draft? if record.draft?

    collection_policy.update?
  end

  def update?
    show? && (record.draft? || collection_policy.update?)
  end

  def destroy?
    update?
  end

  def duplicate?
    create?
  end

  private

  def own_draft?
    record.draft_owner_id == membership.user_id
  end

  def collection_policy
    CollectionPolicy.new(membership, record.collection)
  end
end
