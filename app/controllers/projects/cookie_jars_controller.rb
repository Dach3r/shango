module Projects
  class CookieJarsController < AuthenticatedController
    def destroy
      authorize current_project, :use?
      Cookie.for_jar(current_project, current_environment).delete_all
      redirect_to cookies_path, status: :see_other
    end
  end
end
