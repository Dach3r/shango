module Monitoring
  # Every incident of the project, narrowed to the selected environment, newest first.
  class IncidentsController < BaseController
    include EnvironmentScope

    STATES = %w[open resolved].freeze
    PER_PAGE = 25
    MAX_PAGE = 10_000

    def index
      authorize current_project, :use?
      @state = params[:state].presence_in(STATES)
      @page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
      incidents = current_project.incidents.where(uptime_monitor: current_project.uptime_monitors.in_environment(scope_environment)).recent
      incidents = @state == "open" ? incidents.open : incidents.where.not(resolved_at: nil) if @state
      rows = incidents.includes(:uptime_monitor).strict_loading.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = rows.size > PER_PAGE
      @incidents = rows.first(PER_PAGE)
    end
  end
end
