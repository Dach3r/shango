module Network
  class WorkspacesController < BaseController
    def show
      @tool = Network::Tools.find(params[:kind].presence || "dns")
    end
  end
end
