module SidebarState
  extend ActiveSupport::Concern

  COOKIE_KEY = :sidebar_collapsed

  included do
    helper_method :sidebar_collapsed?
  end

  private

  def sidebar_collapsed?
    cookies[COOKIE_KEY] == "true"
  end
end
