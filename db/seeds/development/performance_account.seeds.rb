# A single development account whose project holds a real, public API (Restful-Booker, https://restful-booker.herokuapp.com)
# imported from its Postman collection and environment (db/seeds/development/fixtures), so the API Client can be tried against
# live requests. Rebuild it from scratch with SEED_RESET=1.
module Seeds
  class DevelopmentAccount
    EMAIL = "dev@shango.test".freeze
    PASSWORD = "password".freeze
    PROJECT_NAME = "Restful Booker".freeze
    FIXTURES = Rails.root.join("db/seeds/development/fixtures")

    def self.call
      new(reset: ENV["SEED_RESET"].present?).call
    end

    def initialize(reset: false)
      @reset = reset
    end

    def call
      user = User.find_by(email: EMAIL)
      if user
        return puts("   #{EMAIL} already exists; run with SEED_RESET=1 to rebuild it") unless @reset

        wipe(user)
      end

      ActiveRecord::Base.transaction { build }
      puts "   Sign in with #{EMAIL} / #{PASSWORD}"
    end

    private

    def wipe(user)
      project_ids = Membership.where(user:).pluck(:project_id)
      user.update_columns(current_membership_id: nil)
      Project.where(id: project_ids).destroy_all
      user.destroy!
    end

    def build
      user = User.new(email: EMAIL, first_name: "Dev", last_name: "Tester", password: PASSWORD, password_confirmation: PASSWORD)
      user.skip_confirmation!
      user.save!

      project = Project.create_with_owner(user, name: PROJECT_NAME, icon: "rocket")
      membership = user.memberships.find_by!(project:)
      user.update!(current_membership_id: membership.id)

      %w[collection environment].each do |kind|
        result = ApiClient::Imports::Import.call(project:, creator: user, content: FIXTURES.join("restful_booker.postman_#{kind}.json").read)
        raise result.error if result.failure?
      end

      membership.update!(current_environment: project.environments.first)
    end
  end
end

Seeds::DevelopmentAccount.call
