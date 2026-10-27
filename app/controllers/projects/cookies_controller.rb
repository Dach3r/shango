module Projects
  class CookiesController < AuthenticatedController
    before_action :require_frame, only: :index

    def index
      @cookies = Cookie.for_jar(current_project, current_environment).live.ordered
    end

    def destroy
      Cookie.for_jar(current_project, current_environment).find(params[:id]).destroy
      redirect_to cookies_path, status: :see_other
    end

    private

    def require_frame
      redirect_to workbench_root_path unless turbo_frame_request?
    end
  end
end
