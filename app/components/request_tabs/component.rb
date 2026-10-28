class RequestTabs::Component < ApplicationComponent
  TAB = "group flex max-w-52 shrink-0 items-center border-r border-b border-line text-xs transition hover:bg-field"

  CLOSE = "mr-2 flex size-5 shrink-0 items-center justify-center text-muted opacity-0 transition hover:bg-ink/10 hover:text-ink focus-visible:opacity-100 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-accent/50 group-hover:opacity-100"

  DRAFT_CLOSE = CLOSE.sub("opacity-0 ", "")

  ITEM = "#{RequestTree::Menu::Component::ITEM} disabled:cursor-not-allowed disabled:text-faint disabled:hover:bg-transparent disabled:hover:text-faint"

  # requests: the ones the user has open as tabs; current_request_id highlights the one being edited;
  # unsaved_ids marks the saved requests whose edits are kept but not saved.
  def initialize(requests:, membership:, current_request_id: nil, unsaved_ids: [])
    @requests = requests
    @membership = membership
    @current_request_id = current_request_id
    @unsaved_ids = unsaved_ids
  end

  private

  def self_close
    { data: { action: "submit->request-tabs#confirmClose", request_tabs_side: "self" } }
  end

  def side_closable?(index)
    { left: index.positive?, right: index < @requests.size - 1 }
  end

  def duplicable?(api_request)
    ApiRequestPolicy.new(@membership, api_request).duplicate?
  end

  def current?(api_request)
    api_request.id == @current_request_id
  end

  def unsaved?(api_request)
    @unsaved_ids.include?(api_request.id)
  end

  # Closing it would drop edits: unsaved changes of a saved request or a draft that is no longer untouched.
  def confirm_close?(api_request)
    unsaved?(api_request) || (api_request.draft? && !api_request.untouched_draft?)
  end

  def confirm_message(api_request)
    t("components.request_tabs.confirm_close", name: api_request.name)
  end

  def draft_close_icon(hint = t("components.request_tabs.draft_hint"))
    safe_join([
      tag.span(class: "size-2 rounded-full bg-muted group-hover:hidden group-focus-within:hidden", title: hint),
      lucide_icon("x", class: "hidden size-3 group-hover:block group-focus-within:block")
    ])
  end

  def classes(api_request)
    class_names(TAB, "border-b-transparent bg-ink/[0.05] font-medium text-ink hover:bg-ink/[0.05]" => current?(api_request), "text-muted" => !current?(api_request))
  end
end
