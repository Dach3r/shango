module Network
  class WorkspacesController < BaseController
    def show
      @kind = params[:kind].presence || "dns"
    end
  end
end
