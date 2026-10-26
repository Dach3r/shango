class ThemesController < ApplicationController
  def update
    theme = Theming.supported(params[:theme])
    cookies[Theming::COOKIE_KEY] = { value: theme, expires: 1.year.from_now, same_site: :lax } if theme

    redirect_back_or_to "/", status: :see_other
  end
end
