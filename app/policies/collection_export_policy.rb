# An export (and the file it holds) belongs to the member who asked for it.
class CollectionExportPolicy < ApplicationPolicy
  def show?
    same_project? && record.user_id == membership.user_id
  end

  def download?
    show?
  end
end
