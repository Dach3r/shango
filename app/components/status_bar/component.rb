class StatusBar::Component < ApplicationComponent
  def initialize(environments: nil, current_environment: nil, sidebar_toggle: false)
    @environments = environments
    @current_environment = current_environment
    @sidebar_toggle = sidebar_toggle
  end
end
