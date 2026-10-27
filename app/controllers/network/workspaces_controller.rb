module Network
  # One page per tool (`/network`, `/network/ports`, `/network/ping`); a saved run has its own address, see ChecksController.
  class WorkspacesController < BaseController
    def show
      @kind = params[:kind].presence || "dns"
    end
  end
end
