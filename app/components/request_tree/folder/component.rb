class RequestTree::Folder::Component < ApplicationComponent
  # manage: whether the member may change the folder's collection; it decides if the folder can be dragged, renamed or acted on.
  def initialize(folder:, branch:, current_request_id: nil, closed_ids: [], manage: true)
    @folder = folder
    @manage = manage
    @branch = branch
    @current_request_id = current_request_id
    @closed_ids = closed_ids
  end

  private

  def wrapper_attributes
    return {} unless @manage

    { data: { controller: "context-menu", action: "contextmenu->context-menu#open" } }
  end

  def summary_attributes
    return { data: { collection_id: @folder.collection_id, folder_id: @folder.id, action: "click->tree#summaryClick dblclick->tree#summaryDoubleClick" } } unless @manage

    {
      draggable: true, data: {
        drag_kind: "folder", drag_id: @folder.id, collection_id: @folder.collection_id, folder_id: @folder.id, drop_mode: "into", position_url: workbench_folder_position_path(@folder),
        action: "dragstart->tree#dragStart dragend->tree#dragEnd click->tree#summaryClick dblclick->tree#summaryDoubleClick"
      }
    }
  end

  def name_attributes
    return {} unless @manage

    { data: { controller: "inline-rename", inline_rename_url_value: workbench_folder_path(@folder), inline_rename_param_value: "folder", action: "dblclick->inline-rename#edit" } }
  end
end
