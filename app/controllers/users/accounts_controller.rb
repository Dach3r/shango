module Users
  class AccountsController < AuthenticatedController
    before_action :require_frame

    def show
    end

    private

    def require_frame
      redirect_to workbench_root_path unless turbo_frame_request?
    end
  end
end
