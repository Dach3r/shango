class RequestTree::Folder::Component < ApplicationComponent
  def initialize(folder:, branch:, current_request_id: nil)
    @folder = folder
    @branch = branch
    @current_request_id = current_request_id
  end
end
