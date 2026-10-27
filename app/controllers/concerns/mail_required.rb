# For screens that only make sense when the instance can send email.
module MailRequired
  extend ActiveSupport::Concern

  included do
    before_action :require_mailing
  end

  private

  def require_mailing
    redirect_to new_user_session_path, alert: t("mailing.disabled"), status: :see_other unless Shango::Mailing.enabled?
  end
end
