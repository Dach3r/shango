module Monitoring
  class ChannelsController < BaseController
    REVEAL = :monitoring_revealed_channel

    before_action :find_channel, only: %i[edit update destroy]
    before_action :find_origin, only: %i[new create]

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
      return render(:new, status: :unprocessable_content) unless Monitoring::Channels::Save.call(channel: @channel, attributes: channel_params, actor: current_user).success?

      session[REVEAL] = @channel.id if @channel.webhook?
      return redirect_to(monitoring_channels_path, notice: t(".created"), status: :see_other) unless @origin

      Monitoring::Monitors::Update.call(monitor: @origin, attributes: {}, channels: @origin.notification_channels.to_a << @channel, actor: current_user)
      redirect_to (@channel.webhook? ? monitoring_channels_path : monitoring_monitor_path(@origin)), notice: t(".connected", monitor: @origin.name), status: :see_other
    end

    def update
      authorize @channel
      return render(:edit, status: :unprocessable_content) unless Monitoring::Channels::Save.call(channel: @channel, attributes: channel_params, actor: current_user).success?

      redirect_to monitoring_channels_path, notice: t(".updated"), status: :see_other
    end

    def destroy
      authorize @channel
      Monitoring::Channels::Destroy.call(channel: @channel, actor: current_user)
      redirect_to monitoring_channels_path, notice: t(".destroyed"), status: :see_other
    end

    private

    # The monitor a new channel is created for (from its settings), connected to it once created; only one the user may edit.
    def find_origin
      monitor = current_project.uptime_monitors.find_by(id: params[:monitor_id]) if params[:monitor_id].present?
      @origin = monitor if monitor && policy(monitor).update?
    end

    def kinds
      NotificationChannel.kinds.keys.select { |kind| kind != "email" || Shango::Mailing.enabled? }
    end

    def channel_params
      params.expect(notification_channel: %i[name target locale enabled])
    end
  end
end
