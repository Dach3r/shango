module Users
  # What cancelling an account does to the user's projects: the ones that go away with it and the ones that block it
  # because other members would be left without an owner.
  class AccountImpact
    def initialize(user)
      @user = user
    end

    def doomed
      @doomed ||= owned_projects.reject { |project| others?(project) }
    end

    def blocked
      @blocked ||= owned_projects.select { |project| others?(project) && !co_owned?(project) }
    end

    def blocked?
      blocked.any?
    end

    def requests_count
      @requests_count ||= ApiRequest.where(project_id: doomed.map(&:id)).count
    end

    private

    def owned_projects
      @owned_projects ||= Project.where(id: @user.memberships.active.owner.select(:project_id)).order(:name).to_a
    end

    def others?(project)
      project.memberships.active.where.not(user_id: @user.id).exists?
    end

    def co_owned?(project)
      project.memberships.active.owner.where.not(user_id: @user.id).exists?
    end
  end
end
