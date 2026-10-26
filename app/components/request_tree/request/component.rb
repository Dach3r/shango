class RequestTree::Request::Component < ApplicationComponent
  ROW = "flex items-center gap-2 rounded-lg py-1.5 pr-9 pl-2 text-sm transition hover:bg-field focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/50"

  def initialize(api_request:, active: false)
    @api_request = api_request
    @active = active
  end

  private

  def classes
    class_names(ROW, "bg-field font-medium text-ink" => @active, "text-body" => !@active)
  end
end
