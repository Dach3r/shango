# Data for the `{{variable}}` autocomplete of plain inputs (see ApiClientHelper#variable_autocomplete_data) in screens
# that have no request open: the enabled variables of the selected environment and no response references.
# Secret values are masked, so they never reach the browser.
module VariableAutocomplete
  extend ActiveSupport::Concern

  included do
    helper_method :editor_variables, :editor_responses, :editor_responses_url
  end

  private

  def editor_variables
    return [] unless current_environment

    current_environment.variables.select(&:enabled).map do |variable|
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
