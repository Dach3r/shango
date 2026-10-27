module Users
  # Cancels an account after checking the password. Projects only the user belongs to go away with them; a project that
  # still has other members cannot be left without an owner, so the user must hand it over first.
  class Destroy
    include Serviceable

    def initialize(user:, password:)
      @user = user
      @password = password
    end

    private

    def perform
      return Result.failure(@user, error: :wrong_password) unless @user.valid_password?(@password.to_s)

      blocked = owned_projects.select { |project| others?(project) && !co_owned?(project) }
      return Result.failure(@user, error: :sole_owner, projects: blocked.map(&:name)) if blocked.any?

      User.transaction do
        owned_projects.reject { |project| others?(project) }.each(&:destroy!)
        @user.destroy!
      end
      Result.success(@user)
    end

    def owned_projects
      @owned_projects ||= Project.where(id: @user.memberships.active.owner.select(:project_id)).to_a
    end

    def others?(project)
      project.memberships.active.where.not(user_id: @user.id).exists?
    end

    def co_owned?(project)
      project.memberships.active.owner.where.not(user_id: @user.id).exists?
    end
  end
end
