module Monitoring
  module Channels
    # Creates or changes a notification channel. On a change, a blank URL keeps the current one, since the page never
    # shows it back in full.
    class Save
      include Serviceable

      def initialize(channel:, attributes:)
        @channel = channel
        @attributes = attributes.to_h.stringify_keys
      end

      private

      def perform
        @attributes.delete("target") if @channel.persisted? && !@channel.email? && @attributes["target"].blank?
        @channel.assign_attributes(@attributes)
        @channel.save ? Result.success(@channel) : Result.failure(@channel, error: :invalid)
      end
    end
  end
end
