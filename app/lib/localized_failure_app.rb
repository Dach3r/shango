# Devise renders authentication failures (e.g. "Invalid email or password")
# from Warden, outside the controller's locale switch, so apply the cookie here too.
class LocalizedFailureApp < Devise::FailureApp
  def respond
    I18n.with_locale(Localization.from_cookie(request.cookies[Localization::COOKIE_KEY.to_s])) { super }
  end
end
