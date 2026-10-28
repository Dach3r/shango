class RequestTree::Request::Component < ApplicationComponent
  ROW = "flex items-center gap-2 py-1.5 pr-9 pl-2 text-[0.8125rem] transition hover:bg-field focus:outline-none focus-visible:outline-none"

  # manage: whether the member may change the request, which decides if it can be dragged, renamed or acted on.
  def initialize(api_request:, active: false, manage: true)
    @api_request = api_request
    @active = active
    @manage = manage
  end

  private

  def row_attributes
    return {} unless @manage

    {
      draggable: true, data: {
        drag_kind: "request", drag_id: @api_request.id, collection_id: @api_request.collection_id, folder_id: @api_request.folder_id, drop_mode: "before",
        position_url: workbench_request_position_path(@api_request), controller: "context-menu", action: "dragstart->tree#dragStart dragend->tree#dragEnd contextmenu->context-menu#open"
      }
    }
  end

  def name_attributes
    return {} unless @manage

    {
      data: {
        controller: "inline-rename", inline_rename_url_value: workbench_request_path(@api_request), inline_rename_href_value: workbench_request_path(@api_request),
        inline_rename_param_value: "api_request", action: "click->inline-rename#navigate dblclick->inline-rename#edit"
      }
    }
  end

  def classes
    class_names(ROW, "bg-field font-medium text-ink" => @active, "text-body" => !@active)
  end
end
