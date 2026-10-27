module Projects
  class CookiesController < AuthenticatedController
    before_action :require_frame, only: %i[index new edit]
    before_action :set_cookie, only: %i[edit update destroy]

    def index
      @cookies = jar.live.ordered
    end

    def new
      @cookie = jar.new(path: "/")
    end

    def create
      result = Cookies::Create.call(project: current_project, environment: current_environment, attributes: cookie_attributes)
      return redirect_to(cookies_path, notice: t(".created"), status: :see_other) if result.success?

      @cookie = result.record
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      result = Cookies::Update.call(cookie: @cookie, attributes: cookie_attributes)
      return redirect_to(cookies_path, notice: t(".updated"), status: :see_other) if result.success?

      render :edit, status: :unprocessable_entity
    end

    def destroy
      @cookie.destroy
      redirect_to cookies_path, status: :see_other
    end

    private

    def jar
      Cookie.for_jar(current_project, current_environment)
    end

    def set_cookie
      @cookie = jar.find(params[:id])
    end

    def cookie_attributes
      params.expect(cookie: %i[name value domain path expires_at host_only secure http_only])
    end

    def require_frame
      redirect_to workbench_root_path unless turbo_frame_request?
    end
  end
end
