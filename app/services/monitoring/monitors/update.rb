module Monitoring
  module Monitors
    # Changes a monitor; submitted settings are merged into the current ones. When what is checked changed, a running monitor is checked again right away with the new
    # configuration; checks enqueued before the change are dropped (`config_version`).
    class Update
      include Serviceable

      def initialize(monitor:, attributes:)
        @monitor = monitor
        @attributes = attributes
      end

      private

      def perform
        settings = @attributes["settings"] || @attributes[:settings]
        @monitor.assign_attributes(@attributes.except("settings", :settings))
        @monitor.settings = @monitor.settings.merge(settings.to_h.stringify_keys) if settings
        @monitor.environment_required = @monitor.environment_id.present?
        return Result.failure(@monitor, error: :invalid) unless @monitor.save

        recheck if @monitor.saved_change_to_config_version? && @monitor.enabled
        Result.success(@monitor)
      end

      def recheck
        @monitor.update_columns(next_check_at: Schedule.next_after_change(@monitor))
        MonitorCheckJob.perform_later(@monitor.id, @monitor.config_version)
      end
    end
  end
end
