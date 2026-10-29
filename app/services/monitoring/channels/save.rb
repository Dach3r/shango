module Monitoring
  module Channels
    # Creates or changes a notification channel and records it in the project's activity. On a change, a blank URL
    # keeps the current one, since the page never shows it back in full.
    class Save
      include Serviceable

      def initialize(channel:, attributes:, actor: nil)
        @channel = channel
        @attributes = attributes.to_h.stringify_keys
        @actor = actor
      end

      private

      def perform
        @attributes.delete("target") if @channel.persisted? && !@channel.email? && @attributes["target"].blank?
        @channel.assign_attributes(@attributes)
        kind = @channel.new_record? ? :channel_created : :channel_updated
        return Result.failure(@channel, error: :invalid) unless @channel.save

        changed = (@channel.saved_changes.keys - %w[updated_at]).any?
        AuditEvents::Record.call(project: @channel.project, kind:, actor: @actor, name: @channel.name) if changed
        Result.success(@channel)
      end
    end
  end
end
