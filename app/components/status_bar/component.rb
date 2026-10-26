class StatusBar::Component < ApplicationComponent
  def initialize(user:, environments: nil, current_environment: nil)
    @user = user
    @environments = environments
    @current_environment = current_environment
  end
end
