module Projects
  module Environments
    class Create
      include Serviceable

      def initialize(project:, attributes:)
        @project = project
        @attributes = attributes
      end

      private

      def perform
        environment = @project.environments.new(Normalize.call(attributes: @attributes))
        environment.save ? Result.success(environment) : Result.failure(environment)
      end
    end
  end
end
