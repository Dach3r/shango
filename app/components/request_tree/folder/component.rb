class RequestTree::Folder::Component < ApplicationComponent
  def initialize(folder:, branch:, current_request_id: nil, closed_ids: [])
    @folder = folder
    @branch = branch
    @current_request_id = current_request_id
    @closed_ids = closed_ids
  end
end
