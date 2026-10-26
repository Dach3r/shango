class RequestTree::Request::Component < ApplicationComponent
  ROW = "flex items-center gap-2 py-1.5 pr-9 pl-2 text-sm transition hover:bg-field focus:outline-none focus-visible:outline-none"

  def initialize(api_request:, active: false)
    @api_request = api_request
    @active = active
  end

  private

  def classes
    class_names(ROW, "bg-field font-medium text-ink" => @active, "text-body" => !@active)
  end
end
