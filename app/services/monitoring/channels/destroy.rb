module Monitoring
  module Channels
    # Deletes an alert channel with its deliveries and monitor links, and records it in the project's activity.
    class Destroy
      include Serviceable

      def initialize(channel:, actor: nil)
        @channel = channel
        @actor = actor
      end

      private

      def perform
        @channel.destroy!
        AuditEvents::Record.call(project: @channel.project, kind: :channel_deleted, actor: @actor, name: @channel.name)
        Result.success(@channel)
      end
    end
  end
end
