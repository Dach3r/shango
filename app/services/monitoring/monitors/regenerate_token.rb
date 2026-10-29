module Monitoring
  module Monitors
    # Gives a push monitor a new secret token; the old one stops working at once. Returns the token to show once.
    class RegenerateToken
      include Serviceable

      def initialize(monitor:, actor: nil)
        @monitor = monitor
        @actor = actor
      end

      private

      def perform
        token = @monitor.regenerate_push_token
        @monitor.save!
        AuditEvents::Record.call(project: @monitor.project, kind: :monitor_updated, actor: @actor, name: @monitor.name)
        Result.success(@monitor, push_token: token)
      end
    end
  end
end
