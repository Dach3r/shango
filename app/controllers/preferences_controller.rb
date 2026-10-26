class PreferencesController < ApplicationController
  PREFERENCES = {
    theme: { source: Theming, options: {} },
    zoom: { source: Zooming, options: {} },
    locale: { source: Localization, options: { httponly: true } }
  }.freeze

  def update
    PREFERENCES.each do |param, config|
      value = config[:source].supported(params[param])
      next unless value

      cookies[config[:source]::COOKIE_KEY] = {
        value:, expires: 1.year.from_now, same_site: :lax, **config[:options]
      }
    end

    redirect_back_or_to "/", status: :see_other
  end
end
