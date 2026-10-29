module Monitoring
  module Channels
    class SecretsController < BaseController
      before_action :find_channel

      def create
        authorize @channel, :update?
        return head(:not_found) unless @channel.webhook?

        @channel.regenerate_signing_secret
        @channel.save!
        session[ChannelsController::REVEAL] = @channel.id
        redirect_to monitoring_channels_path, notice: t(".regenerated"), status: :see_other
      end
    end
  end
end
