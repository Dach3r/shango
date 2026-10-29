module Monitoring
  module Channels
    class TestsController < BaseController
      before_action :find_channel
      throttle :network, by: -> { current_user.id }

      def create
        authorize @channel, :test?
        Monitoring::Channels::SendTest.call(channel: @channel)
        redirect_to monitoring_channels_path, notice: t(".queued"), status: :see_other
      end
    end
  end
end
