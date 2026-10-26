class DraftTabs::Component < ApplicationComponent
  TAB = "flex max-w-48 shrink-0 items-center gap-2 rounded-lg px-3 py-1.5 text-sm transition hover:bg-field focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50"

  # drafts: the user's collection-less requests, shown as tabs; current_request_id highlights the open one.
  def initialize(drafts:, current_request_id: nil)
    @drafts = drafts
    @current_request_id = current_request_id
  end

  private

  def classes(api_request)
    class_names(TAB, "bg-field font-medium text-ink" => api_request.id == @current_request_id, "text-muted" => api_request.id != @current_request_id)
  end
end
