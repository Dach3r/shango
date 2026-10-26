module Workbench
  # Shared behavior for the API Client feature: sidebar tree and modal form errors.
  class BaseController < AuthenticatedController
    helper_method :workspace_tree, :open_requests, :editor_variables

    private

    def workspace_tree
      @workspace_tree ||= ApiClient::Tree::Load.call(project: current_project)
    end

    def open_requests
      @open_requests ||= ApiClient::Tabs::Load.call(project: current_project, user: current_user)
    end

    # Enabled variables of the selected environment, offered as autocomplete and highlighted in the editors.
    # Secret values are masked, so they never reach the browser.
    def editor_variables
      return [] unless current_environment

      current_environment.variables.select(&:enabled).map do |variable|
        { name: variable.key, set: variable.value.present?, value: variable.masked_value, secret: variable.secret, url: environment_variable_path(current_environment, variable) }
      end
    end

    # Re-renders a modal form (inside the "modal" frame) with its validation errors.
    def render_form_errors(partial: "form")
      render turbo_stream: turbo_stream.update("modal", partial: "#{controller_path}/#{partial}"), status: :unprocessable_entity
    end
  end
end
