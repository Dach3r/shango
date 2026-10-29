module Monitoring
  class ChannelsController < BaseController
    REVEAL = :monitoring_revealed_channel

    before_action :find_channel, only: %i[edit update destroy]

    def index
      authorize current_project, :use?
      @channels = current_project.notification_channels.ordered.includes(:uptime_monitors).to_a
      @latest = NotificationDelivery.where(notification_channel_id: @channels.map(&:id)).select("DISTINCT ON (notification_channel_id) *")
                                    .order(:notification_channel_id, created_at: :desc).index_by(&:notification_channel_id)
      revealed = session.delete(REVEAL)
      @revealed = @channels.find { |channel| channel.id == revealed }
    end

    def new
      @channel = current_project.notification_channels.new(kind: params[:kind].presence_in(kinds), locale: I18n.locale, creator: current_user)
      authorize @channel
    end

    def edit
      authorize @channel
    end

    def create
      @channel = current_project.notification_channels.new(kind: params.dig(:notification_channel, :kind).presence_in(kinds), creator: current_user)
      authorize @channel
      return render(:new, status: :unprocessable_content) unless Monitoring::Channels::Save.call(channel: @channel, attributes: channel_params).success?

      session[REVEAL] = @channel.id if @channel.webhook?
      redirect_to monitoring_channels_path, notice: t(".created"), status: :see_other
    end

    def update
      authorize @channel
      return render(:edit, status: :unprocessable_content) unless Monitoring::Channels::Save.call(channel: @channel, attributes: channel_params).success?

      redirect_to monitoring_channels_path, notice: t(".updated"), status: :see_other
    end

    def destroy
      authorize @channel
      @channel.destroy!
      redirect_to monitoring_channels_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def kinds
      NotificationChannel.kinds.keys.select { |kind| kind != "email" || Shango::Mailing.enabled? }
    end

    def channel_params
      params.expect(notification_channel: %i[name target locale enabled])
    end
  end
end
