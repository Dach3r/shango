class DraftTabs::Component < ApplicationComponent
  TAB = "group relative flex max-w-52 shrink-0 items-center rounded-md text-xs transition hover:bg-field after:absolute after:-right-1 after:top-1/2 after:h-4 after:w-px after:-translate-y-1/2 after:bg-line"

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
