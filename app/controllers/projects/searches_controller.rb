module Projects
  # Answers the command palette (Cmd/Ctrl+K) with the pages, requests and monitors that match what was typed.
  class SearchesController < AuthenticatedController
    def show
      authorize current_project, :use?
      @entries = Projects::Searches::Run.call(project: current_project, query: params[:q]).data[:entries].group_by(&:group)
    end
  end
end
