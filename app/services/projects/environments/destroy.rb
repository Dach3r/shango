module Projects
  module Environments
    class Destroy
      include Serviceable

      def initialize(environment:, actor: nil)
        @environment = environment
        @actor = actor
      end

      private

      def perform
        return Result.failure(@environment) unless @environment.destroy

        AuditEvents::Record.call(project: @environment.project, kind: :environment_deleted, actor: @actor, name: @environment.name)
        Result.success(@environment)
      end
    end
  end
end
