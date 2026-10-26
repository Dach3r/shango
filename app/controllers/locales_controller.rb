class LocalesController < ApplicationController
  def update
    locale = Localization.supported(params[:locale])
    cookies[Localization::COOKIE_KEY] = { value: locale, expires: 1.year.from_now, same_site: :lax, httponly: true } if locale

    redirect_back_or_to "/", status: :see_other
  end
end
