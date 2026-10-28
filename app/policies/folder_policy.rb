# Folders follow their collection: whoever manages the collection manages its folders.
class FolderPolicy < ApplicationPolicy
  def show?
    collection_policy.show?
  end

  def create?
    collection_policy.update?
  end

  def update?
    collection_policy.update?
  end

  def destroy?
    collection_policy.update?
  end

  private

  def collection_policy
    CollectionPolicy.new(membership, record.collection)
  end
end
