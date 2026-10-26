module SessionHelpers
  # A signed-in user with an active owner membership in a fresh project.
  def sign_in_with_project(user = create(:user))
    project = create(:project)
    membership = create(:membership, :owner, user:, project:)
    user.update!(current_membership: membership)
    sign_in user
    [user, project, membership]
  end
end

RSpec.configure { |config| config.include SessionHelpers, type: :request }
