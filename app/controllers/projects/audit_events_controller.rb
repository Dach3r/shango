module Projects
  # The project's team history, newest first, for its owners.
  class AuditEventsController < AuthenticatedController
    PER_PAGE = 25
    MAX_PAGE = 10_000

    def index
      authorize current_project, :manage_members?
      @page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
      events = current_project.audit_events.recent.includes(:actor, :target).strict_loading.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = events.size > PER_PAGE
      @events = events.first(PER_PAGE)
    end
  end
end
