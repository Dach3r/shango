class DraftTabs::Component < ApplicationComponent
  TAB = "group flex max-w-52 shrink-0 items-center border-r border-line text-xs transition hover:bg-field"

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
