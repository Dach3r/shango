module PolicyHelpers
  def owner_membership(project: create(:project), user: create(:user))
    create(:membership, :owner, project:, user:)
  end

  def member_membership(project: create(:project), user: create(:user))
    create(:membership, project:, user:)
  end
end

RSpec.configure { |config| config.include PolicyHelpers, type: :policy }
