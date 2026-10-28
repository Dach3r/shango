module Projects
  module Environments
    class Create
      include Serviceable

      def initialize(project:, creator:, attributes:)
        @project = project
        @creator = creator
        @attributes = attributes
      end

      private

      def perform
        environment = @project.environments.new(Normalize.call(attributes: @attributes).merge(creator: @creator))
        environment.save ? Result.success(environment) : Result.failure(environment)
      end
    end
  end
end
