class RequestTree::Collection::Component < ApplicationComponent
  # manage: whether the member may change the collection; it decides if the branch can be renamed, dragged into or acted on.
  def initialize(branch:, current_request_id: nil, closed_ids: [], manage: true)
    @branch = branch
    @manage = manage
    @current_request_id = current_request_id
    @closed_ids = closed_ids
  end

  private

  def collection
    @branch.collection
  end

  def wrapper_attributes
    return {} unless @manage

    { data: { controller: "context-menu", action: "contextmenu->context-menu#open" } }
  end

  def summary_attributes
    { data: { action: "click->tree#summaryClick dblclick->tree#summaryDoubleClick", collection_id: collection.id, folder_id: "", **(@manage ? { drop_mode: "into" } : {}) } }
  end

  def name_attributes
    return {} unless @manage

    { data: { controller: "inline-rename", inline_rename_url_value: workbench_collection_path(collection), inline_rename_param_value: "collection", action: "dblclick->inline-rename#edit" } }
  end
end
