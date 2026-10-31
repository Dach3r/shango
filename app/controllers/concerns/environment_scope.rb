# Narrows what a screen lists to the environment the member works in, unless the page asks for every environment
# (`?environment=all`). See `UptimeMonitor.in_environment`.
module EnvironmentScope
  extend ActiveSupport::Concern

  included do
    helper_method :scope_environment
  end

  private

  def scope_environment
    params[:environment] == "all" ? nil : current_environment
  end
end
