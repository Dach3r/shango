class EnvironmentSwitcher::Component < ApplicationComponent
  def initialize(environments:, current_environment:)
    @environments = environments
    @current_environment = current_environment
  end
end
