class RequestTabs::Component < ApplicationComponent
  TAB = "group flex max-w-52 shrink-0 items-center border-r border-b border-line text-xs transition hover:bg-field"

  CLOSE = "mr-2 flex size-5 shrink-0 items-center justify-center text-muted opacity-0 transition hover:bg-ink/10 hover:text-ink focus-visible:opacity-100 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50 group-hover:opacity-100"

  ITEM = "#{RequestTree::Menu::Component::ITEM} disabled:cursor-not-allowed disabled:text-faint disabled:hover:bg-transparent disabled:hover:text-faint"

  # requests: the ones the user has open as tabs; current_request_id highlights the one being edited.
  def initialize(requests:, current_request_id: nil)
    @requests = requests
    @current_request_id = current_request_id
  end

  private

  def side_closable?(index)
    { left: index.positive?, right: index < @requests.size - 1 }
  end

  def current?(api_request)
    api_request.id == @current_request_id
  end

  def classes(api_request)
    class_names(TAB, "border-b-transparent bg-ink/[0.05] font-medium text-ink hover:bg-ink/[0.05]" => current?(api_request), "text-muted" => !current?(api_request))
  end
end
