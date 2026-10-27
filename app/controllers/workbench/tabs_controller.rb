module Workbench
  # Closes several of the user's tabs at once: the ones left or right of a tab, or all of them.
  # `keep` lists the tabs the user chose not to close.
  class TabsController < BaseController
    def destroy
      ApiClient::Tabs::CloseMany.call(api_requests: closing, user: current_user)
      @open_requests = nil
      redirect_to destination, status: :see_other
    end

    private

    def closing
      side_tabs.reject { |tab| Array(params[:keep]).include?(tab.id) }
    end

    def side_tabs
      tabs = open_requests
      pivot = tabs.index { |tab| tab.id == params[:request_id] }
      return tabs if params[:side] == "all"
      return [] unless pivot

      case params[:side]
      when "left" then tabs.first(pivot)
      when "right" then tabs.drop(pivot + 1)
      else []
      end
    end

    # Stays on the current request while its tab is open, otherwise falls back to the last remaining tab.
    def destination
      remaining = open_requests
      target = remaining.find { |tab| tab.id == params[:current] } || remaining.last
      target ? workbench_request_path(target) : workbench_root_path
    end
  end
end
