class RequestTree::Collection::Component < ApplicationComponent
  def initialize(branch:, current_request_id: nil, closed_ids: [])
    @branch = branch
    @current_request_id = current_request_id
    @closed_ids = closed_ids
  end

  private

  def collection
    @branch.collection
  end
end
