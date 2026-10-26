class RequestTree::Collection::Component < ApplicationComponent
  def initialize(branch:, current_request_id: nil)
    @branch = branch
    @current_request_id = current_request_id
  end

  private

  def collection
    @branch.collection
  end
end
