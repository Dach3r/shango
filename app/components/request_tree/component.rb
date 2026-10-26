class RequestTree::Component < ApplicationComponent
  # branches: ApiClient::Tree::Load::Branch list; current_request_id highlights the open request.
  def initialize(branches:, folder_toggle:, current_request_id: nil)
    @branches = branches
    @folder_toggle = folder_toggle
    @current_request_id = current_request_id
  end
end
