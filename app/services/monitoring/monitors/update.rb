module Monitoring
  module Monitors
    # Changes a monitor; submitted settings are merged into the current ones, and `channels` (when given) replace the
    # ones it alerts. When what is checked changed, a running monitor is checked again right away with the new
    # configuration; checks enqueued before the change are dropped (`config_version`). A real change is recorded in the
    # project's activity.
    class Update
      include Serviceable

      def initialize(monitor:, attributes:, channels: nil, actor: nil)
        @monitor = monitor
        @attributes = attributes
        @channels = channels
        @actor = actor
      end

      private

      def perform
        settings = @attributes["settings"] || @attributes[:settings]
        @monitor.assign_attributes(@attributes.except("settings", :settings))
        @monitor.settings = @monitor.settings.merge(settings.to_h.stringify_keys) if settings
        @monitor.environment_required = @monitor.environment_id.present?
        channel_ids = @monitor.notification_channel_ids.sort
        return Result.failure(@monitor, error: :invalid) unless save

        record(channel_ids)

        recheck if @monitor.saved_change_to_config_version? && @monitor.enabled
        Result.success(@monitor)
      end

      def save
        UptimeMonitor.transaction do
          @monitor.notification_channels = @channels if @channels
          @monitor.save || raise(ActiveRecord::Rollback)
        end
      end

      def record(channel_ids)
        return if (@monitor.saved_changes.keys - %w[updated_at]).empty? && channel_ids == @monitor.notification_channel_ids.sort

        AuditEvents::Record.call(project: @monitor.project, kind: :monitor_updated, actor: @actor, name: @monitor.name)
      end

      def recheck
        @monitor.update_columns(next_check_at: Schedule.next_after_change(@monitor))
        MonitorCheckJob.perform_later(@monitor.id, @monitor.config_version)
      end
    end
  end
end
