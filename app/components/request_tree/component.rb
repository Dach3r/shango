class RequestTree::Component < ApplicationComponent
  # branches: ApiClient::Tree::Load::Branch list; drafts: the user's collection-less requests; current_request_id highlights the open request.
  def initialize(branches:, drafts: [], current_request_id: nil)
    @branches = branches
    @drafts = drafts
    @current_request_id = current_request_id
  end
end
