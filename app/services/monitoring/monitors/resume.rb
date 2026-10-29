module Monitoring
  module Monitors
    # Checks a paused monitor again from scratch: status `pending`, checked on the next dispatch.
    class Resume
      include Serviceable

      def initialize(monitor:, actor: nil, at: Time.current)
        @monitor = monitor
        @actor = actor
        @at = at
      end

      private

      def perform
        @monitor.with_lock do
          @monitor.restart(@at)
          @monitor.update!(enabled: true, failures: 0, next_check_at: @at)
        end
        AuditEvents::Record.call(project: @monitor.project, kind: :monitor_resumed, actor: @actor, name: @monitor.name)
        Result.success(@monitor)
      end
    end
  end
end
