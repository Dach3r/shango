class StatusBar::Component < ApplicationComponent
  def initialize(environments: nil, current_environment: nil, collapsed: false)
    @collapsed = collapsed
    @environments = environments
    @current_environment = current_environment
  end
end
