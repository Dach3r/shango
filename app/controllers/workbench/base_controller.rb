module Workbench
  # Shared behavior for the API Client feature: sidebar tree and modal form errors.
  class BaseController < AuthenticatedController
    helper_method :workspace_tree, :open_requests, :variable_names

    private

    def workspace_tree
      @workspace_tree ||= ApiClient::Tree::Load.call(project: current_project)
    end

    def open_requests
      @open_requests ||= ApiClient::Tabs::Load.call(project: current_project, user: current_user)
    end

    # Names of the selected environment's variables, offered as autocomplete in the editors.
    def variable_names
      current_environment ? current_environment.variables.select(&:enabled).map(&:key) : []
    end

    # Re-renders a modal form (inside the "modal" frame) with its validation errors.
    def render_form_errors(partial: "form")
      render turbo_stream: turbo_stream.update("modal", partial: "#{controller_path}/#{partial}"), status: :unprocessable_entity
    end
  end
end
