class Topbar::Component < ApplicationComponent
  def initialize(user:, title: nil, environments: nil, current_environment: nil)
    @user = user
    @title = title
    @environments = environments
    @current_environment = current_environment
  end
end
