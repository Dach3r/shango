# Base of every policy. The "user" is the signed-in membership, so rules look at the role in the current project
# and never at the account; everything is denied unless a policy opts in.
class ApplicationPolicy
  attr_reader :membership, :record

  def initialize(membership, record)
    @membership = membership
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

  private

  def owner?
    membership.owner?
  end

  def creator?
    record.respond_to?(:creator_id) && record.creator_id.present? && record.creator_id == membership.user_id
  end

  # Records of another project are never reachable, whatever the role.
  def same_project?
    record.respond_to?(:project_id) && record.project_id == membership.project_id
  end

  # Owners manage everything; members only what they created.
  def manage?
    same_project? && (owner? || creator?)
  end
end
