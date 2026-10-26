class RequestTree::Component < ApplicationComponent
  # branches: ApiClient::Tree::Load::Branch list; history_groups: ApiClient::Executions::History groups; current_request_id highlights the open request.
  def initialize(branches:, history_groups:, folder_toggle:, request_open:, collapse_nested: true, current_request_id: nil)
    @branches = branches
    @history_groups = history_groups
    @folder_toggle = folder_toggle
    @request_open = request_open
    @collapse_nested = collapse_nested
    @current_request_id = current_request_id
  end
end
