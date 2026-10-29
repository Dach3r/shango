module Monitoring
  class MonitorsController < BaseController
    FILTERS = %w[up down pending paused].freeze

    before_action :find_monitor, only: %i[show edit update destroy]

    def index
      authorize current_project, :use?
      @filter = params[:status].presence_in(FILTERS)
      @query = params[:q].to_s.strip.first(100)
      all = current_project.uptime_monitors.order(:name).strict_loading
      @overview = Monitoring::Monitors::Overview.call(monitors: all.to_a).data
      @monitors = filtered(all)
    end

    def show
      authorize @monitor
      @report = Monitoring::Monitors::Report.call(monitor: @monitor).record
    end

    def new
      @monitor = current_project.uptime_monitors.new(kind: "http", environment: current_environment, creator: current_user)
      authorize @monitor
    end

    def edit
      authorize @monitor
    end

    def create
      @monitor = current_project.uptime_monitors.new(monitor_params.merge(kind: "http", creator: current_user))
      authorize @monitor
      result = Monitoring::Monitors::Create.call(monitor: @monitor, channels:)
      return redirect_to(monitoring_monitor_path(@monitor), notice: t(".created"), status: :see_other) if result.success?

      render :new, status: :unprocessable_content
    end

    def update
      authorize @monitor
      result = Monitoring::Monitors::Update.call(monitor: @monitor, attributes: monitor_params, channels:, actor: current_user)
      return redirect_to(monitoring_monitor_path(@monitor), notice: t(".updated"), status: :see_other) if result.success?

      render :edit, status: :unprocessable_content
    end

    def destroy
      authorize @monitor
      Monitoring::Monitors::Destroy.call(monitor: @monitor, actor: current_user)
      redirect_to monitoring_root_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def monitor_params
      attributes = params.expect(uptime_monitor: [:name, :environment_id, :interval, :timeout, :confirmations, { settings: %i[url http_method expected_statuses max_response_ms] }]).to_h
      attributes["settings"] = attributes["settings"].merge("mode" => "url") if attributes.key?("settings")
      attributes
    end

    # The channels ticked in the form, only among the project's; nil when the form did not send the list.
    def channels
      ids = params.dig(:uptime_monitor, :notification_channel_ids)
      current_project.notification_channels.where(id: Array(ids).compact_blank).to_a if ids
    end

    def filtered(scope)
      scope = scope.where("name ILIKE :q OR settings->>'url' ILIKE :q", q: "%#{UptimeMonitor.sanitize_sql_like(@query)}%") if @query.present?
      case @filter
      when "paused" then scope.where(enabled: false)
      when nil then scope
      else scope.where(enabled: true, status: @filter)
      end
    end
  end
end
