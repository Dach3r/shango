module VariableAutocomplete
  extend ActiveSupport::Concern

  included do
    helper_method :editor_variables, :editor_responses, :editor_responses_url
  end

  private

  def editor_variables
    return [] unless current_environment

    @editor_variables ||= current_environment.variables.where(enabled: true).map do |variable|
      { name: variable.key, set: variable.value.present?, value: variable.masked_value, secret: variable.secret, url: environment_variable_path(current_environment, variable) }
    end
  end

  def editor_responses
    []
  end

  def editor_responses_url
    nil
  end
end
