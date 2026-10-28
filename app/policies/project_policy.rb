# Project-wide capabilities. Anything a member of the project may do without a specific record goes through `use?`.
class ProjectPolicy < ApplicationPolicy
  def use?
    record.id == membership.project_id
  end

  def import?
    use?
  end

  # Inviting people, handing the project over and reading its activity are owner-only.
  def manage_members?
    use? && membership.owner?
  end
end
