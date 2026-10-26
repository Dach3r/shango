require "rails_helper"

RSpec.describe "Preferences" do
  describe "PATCH /preferences" do
    it "stores supported theme and locale cookies", :aggregate_failures do
      patch preferences_path, params: { theme: "dark", locale: "es" }, headers: { "HTTP_REFERER" => "http://www.example.com/somewhere" }

      expect(response).to redirect_to("http://www.example.com/somewhere")
      expect(response.headers["Set-Cookie"].join).to include("theme=dark", "locale=es")
    end

    it "ignores unsupported values and falls back to root", :aggregate_failures do
      patch preferences_path, params: { theme: "neon", locale: "xx" }

      expect(response).to redirect_to("/")
      expect(response.headers["Set-Cookie"]).to be_nil
    end

    it "renders the page in the cookie locale and theme", :aggregate_failures do
      patch preferences_path, params: { theme: "dark", locale: "es" }
      get new_user_session_path

      expect(response.body).to include("Iniciar sesión")
    end
  end
end
