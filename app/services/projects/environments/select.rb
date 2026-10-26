module Projects
  module Environments
    # Stores the environment a member works with inside a project (blank clears it).
    class Select
      include Serviceable

      def initialize(membership:, environment_id:)
        @membership = membership
        @environment_id = environment_id.presence
      end

      private

      def perform
        environment = @environment_id && @membership.project.environments.find(@environment_id)
        @membership.update!(current_environment: environment)
        Result.success(environment)
      end
    end
  end
end
