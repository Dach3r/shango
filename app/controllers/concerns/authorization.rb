# Pundit on top of the current membership: rules depend on the role in the selected project.
module Authorization
  extend ActiveSupport::Concern

  include Pundit::Authorization

  included do
    rescue_from Pundit::NotAuthorizedError, with: :forbidden
  end

  private

  def pundit_user
    current_membership
  end

  # Browser navigations get a toast on the page they came from; background requests (fetch, JSON) get a bare 403.
  def forbidden
    return head(:forbidden) unless request.headers["Accept"].to_s.include?("html")

    redirect_back_or_to workbench_root_path, alert: t("authorization.forbidden"), status: :see_other
  end
end
