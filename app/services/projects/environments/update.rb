module Projects
  module Environments
    class Update
      include Serviceable

      def initialize(environment:, attributes:, actor: nil)
        @environment = environment
        @attributes = attributes
        @actor = actor
      end

      private

      def perform
        @environment.assign_attributes(Normalize.call(attributes: @attributes))
        return Result.failure(@environment) unless @environment.save

        AuditEvents::Record.call(project: @environment.project, kind: :environment_updated, actor: @actor, name: @environment.name) if @environment.saved_changes?
        Result.success(@environment)
      end
    end
  end
end
