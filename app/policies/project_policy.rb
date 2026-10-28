# Project-wide capabilities. Anything a member of the project may do without a specific record goes through `use?`.
class ProjectPolicy < ApplicationPolicy
  def use?
    record.id == membership.project_id
  end

  def import?
    use?
  end
end
