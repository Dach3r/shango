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
        return Result.failure(environment) unless environment.save

        AuditEvents::Record.call(project: @project, kind: :environment_created, actor: @creator, name: environment.name)
        Result.success(environment)
      end
    end
  end
end
