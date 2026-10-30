module Monitoring
  class MonitorsController < BaseController
    FILTERS = %w[up down pending paused].freeze
    PUSH_TOKEN = :monitoring_push_token

    before_action :find_monitor, only: %i[show edit update destroy]

    def index
      authorize current_project, :use?
      @filter = params[:status].presence_in(FILTERS)
      @query = params[:q].to_s.strip.first(100)
      all = current_project.uptime_monitors.order(:name).includes(api_request: :collection).strict_loading
      @overview = Monitoring::Monitors::Overview.call(monitors: all.to_a).data
      @monitors = filtered(all)
    end

    def show
      authorize @monitor
      @report = Monitoring::Monitors::Report.call(monitor: @monitor).record
      revealed = session.delete(PUSH_TOKEN)
      @push_token = revealed["token"] if revealed.is_a?(Hash) && revealed["id"] == @monitor.id
    end

    def new
      @monitor = current_project.uptime_monitors.new(kind: params[:kind].presence_in(Monitoring::Checks::Run.kinds), environment: current_environment, creator: current_user)
      prefill_from_request
      authorize @monitor
    end

    def edit
      authorize @monitor
    end

    def create
      kind = params.dig(:uptime_monitor, :kind).presence_in(Monitoring::Checks::Run.kinds)
      @monitor = current_project.uptime_monitors.new(monitor_params.merge(kind:, creator: current_user))
      authorize @monitor
      result = Monitoring::Monitors::Create.call(monitor: @monitor, channels:)
      session[PUSH_TOKEN] = { "id" => @monitor.id, "token" => result.data[:push_token] } if result.success? && @monitor.push?
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

    # A monitor started from a saved request (`?kind=http&api_request_id=...`) checks that request.
    def prefill_from_request
      return unless @monitor.http? && params[:api_request_id].present?

      api_request = current_project.api_requests.find_by(id: params[:api_request_id])
      return unless api_request

      @monitor.assign_attributes(api_request:, name: api_request.name.to_s.first(100), mode: "request")
    end

    def monitor_params
      attributes = params.expect(uptime_monitor: [:name, :environment_id, :api_request_id, :interval, :timeout, :confirmations,
                                                   { settings: %i[mode url http_method expected_statuses max_response_ms host port days_before grace] }]).to_h
      return attributes unless attributes.key?("settings")

      mode = attributes.dig("settings", "mode").presence_in(UptimeMonitor::MODES) || "url"
      attributes["settings"] = attributes["settings"].merge("mode" => mode)
      attributes["api_request_id"] = nil if mode == "url"
      attributes
    end

    # The channels ticked in the form, only among the project's; nil when the form did not send the list.
    def channels
      ids = params.dig(:uptime_monitor, :notification_channel_ids)
      current_project.notification_channels.where(id: Array(ids).compact_blank).to_a if ids
    end

    def filtered(scope)
      scope = scope.where("name ILIKE :q OR settings->>'url' ILIKE :q OR settings->>'host' ILIKE :q", q: "%#{UptimeMonitor.sanitize_sql_like(@query)}%") if @query.present?
      case @filter
      when "paused" then scope.where(enabled: false)
      when nil then scope
      else scope.where(enabled: true, status: @filter)
      end
    end
  end
end
