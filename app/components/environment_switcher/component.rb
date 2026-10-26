class EnvironmentSwitcher::Component < ApplicationComponent
  def initialize(environments:, current_environment:, compact: false)
    @environments = environments
    @current_environment = current_environment
    @compact = compact
  end
end
