class RequestTree::Component < ApplicationComponent
  # branches: ApiClient::Tree::Load::Branch list; history_groups: ApiClient::Executions::History groups; current_request_id highlights the open request; closed_ids (ids as strings, from the tree cookie) render collapsed.
  # membership: the viewer's, which decides what each collection offers (see CollectionPolicy).
  def initialize(branches:, history_groups:, folder_toggle:, request_open:, membership:, collapse_nested: true, current_request_id: nil, closed_ids: [])
    @branches = branches
    @membership = membership
    @history_groups = history_groups
    @folder_toggle = folder_toggle
    @request_open = request_open
    @collapse_nested = collapse_nested
    @current_request_id = current_request_id
    @closed_ids = closed_ids
  end

  private

  def manage?(branch)
    CollectionPolicy.new(@membership, branch.collection).update?
  end
end
