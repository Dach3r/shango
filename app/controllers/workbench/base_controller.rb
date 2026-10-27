module Workbench
  # Shared behavior for the API Client feature: sidebar tree and modal form errors.
  class BaseController < AuthenticatedController
    include VariableAutocomplete

    helper_method :workspace_tree, :workspace_history, :open_requests, :unsaved_request_ids, :editor_variables_url

    private

    def workspace_history
      @workspace_history ||= ApiClient::Executions::History.call(project: current_project, user: current_user)
    end

    def workspace_tree
      @workspace_tree ||= ApiClient::Tree::Load.call(project: current_project)
    end

    def open_requests
      @open_requests ||= ApiClient::Tabs::Load.call(project: current_project, user: current_user)
    end

    # Open tabs whose edits are kept unsaved (see ApiClient::Requests::Stash).
    def unsaved_request_ids
      @unsaved_request_ids ||= ApiClient::Requests::Stash.ids(requests: open_requests, user: current_user)
    end

    # Where the editors create a variable that is not defined yet.
    def editor_variables_url
      environment_variables_path(current_environment) if current_environment
    end

    # Other requests of the open request's collection, offered as `{{response.…}}` sources (drafts have none).
    # Read from the sidebar tree, which already holds them.
    def editor_responses
      return [] unless editor_responses_url

      @editor_responses ||= begin
        branch = workspace_tree.find { |item| item.collection.id == @api_request.collection_id }
        siblings = branch.all_requests.reject { |sibling| sibling.id == @api_request.id }
        siblings.sort_by { |sibling| [sibling.name.downcase, sibling.name] }.map do |sibling|
          { id: sibling.id, name: sibling.name, method: sibling.http_method, folder: branch.folder(sibling.folder_id)&.name }
        end
      end
    end

    # Where the editors preview what a response reference resolves to.
    def editor_responses_url
      workbench_request_response_reference_path(@api_request) if @api_request&.persisted? && @api_request.collection_id
    end

    # Re-renders a modal form (inside the "modal" frame) with its validation errors.
    def render_form_errors(partial: "form")
      render turbo_stream: turbo_stream.update("modal", partial: "#{controller_path}/#{partial}"), status: :unprocessable_entity
    end
  end
end
