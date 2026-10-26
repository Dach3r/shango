class StatusBar::Component < ApplicationComponent
  def initialize(environments: nil, current_environment: nil)
    @environments = environments
    @current_environment = current_environment
  end
end
