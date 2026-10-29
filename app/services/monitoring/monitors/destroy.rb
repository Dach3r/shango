module Monitoring
  module Monitors
    # Deletes a monitor with its results, rollups, incidents and channel links, and records it in the project's activity.
    class Destroy
      include Serviceable

      def initialize(monitor:, actor: nil)
        @monitor = monitor
        @actor = actor
      end

      private

      def perform
        @monitor.destroy!
        AuditEvents::Record.call(project: @monitor.project, kind: :monitor_deleted, actor: @actor, name: @monitor.name)
        Result.success(@monitor)
      end
    end
  end
end
