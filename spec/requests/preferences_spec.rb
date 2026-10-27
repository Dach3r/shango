require "rails_helper"

RSpec.describe "Preferences" do
  describe "PATCH /preferences" do
    it "stores supported theme and locale cookies", :aggregate_failures do
      patch preferences_path, params: { theme: "dark", locale: "es" }, headers: { "HTTP_REFERER" => "http://www.example.com/somewhere" }

      expect(response).to redirect_to("http://www.example.com/somewhere")
      expect(response.headers["Set-Cookie"].join).to include("theme=dark", "locale=es")
    end

    it "stores a supported zoom cookie and renders it on the page", :aggregate_failures do
      sign_in create(:user)
      patch preferences_path, params: { zoom: "125" }
      get new_project_path

      expect(response.body).to include('data-zoom="125"')
    end

    it "defaults the zoom to 95" do
      sign_in create(:user)
      get new_project_path

      expect(response.body).to include('data-zoom="95"')
    end

    it "ignores the zoom cookie on devise pages" do
      patch preferences_path, params: { zoom: "125" }
      get new_user_session_path

      expect(response.body).to include('data-zoom="100"')
    end

    it "ignores unsupported values and falls back to root", :aggregate_failures do
      patch preferences_path, params: { theme: "neon", locale: "xx", zoom: "999" }

      expect(response).to redirect_to("/")
      expect(response.headers["Set-Cookie"]).to be_nil
    end

    it "renders the page in the cookie locale and theme", :aggregate_failures do
      patch preferences_path, params: { theme: "dark", locale: "es" }
      get new_user_session_path

      expect(response.body).to include("Iniciar sesión")
    end
  end

  describe "tampered values" do
    it "ignores case variants, whitespace and blanks", :aggregate_failures do
      patch preferences_path, params: { theme: "DARK", locale: " es", zoom: "125 " }
      expect(response.headers["Set-Cookie"]).to be_nil

      patch preferences_path, params: { theme: "", locale: "", zoom: "" }
      expect(response.headers["Set-Cookie"]).to be_nil
    end

    it "ignores array and hash params without raising", :aggregate_failures do
      patch preferences_path, params: { theme: %w[dark], locale: { es: "1" }, zoom: %w[125] }

      expect(response).to redirect_to("/")
      expect(response.headers["Set-Cookie"]).to be_nil
    end

    it "stores only the supported values of a mixed request", :aggregate_failures do
      patch preferences_path, params: { theme: "dark", locale: "xx", zoom: "125" }

      expect(response.headers["Set-Cookie"].join).to include("theme=dark", "zoom=125")
      expect(response.headers["Set-Cookie"].join).not_to include("locale=")
    end

    it "marks the locale cookie httponly and lax", :aggregate_failures do
      patch preferences_path, params: { locale: "es" }

      cookie = Array(response.headers["Set-Cookie"]).join
      expect(cookie).to match(/httponly/i)
      expect(cookie).to match(/samesite=lax/i)
    end

    it "falls back to the default locale and theme when the cookies are tampered", :aggregate_failures do
      cookies[:locale] = "klingon"
      cookies[:theme] = "<script>"
      get new_user_session_path

      expect(response.body).to include('lang="en"')
      expect(response.body).not_to include("<script>alert")
    end

    it "falls back to the default zoom when the cookie is tampered" do
      sign_in create(:user)
      cookies[:zoom] = "9999"
      get new_project_path

      expect(response.body).to include('data-zoom="95"')
    end

    it "does not need authentication" do
      patch preferences_path, params: { locale: "es" }

      expect(response).to have_http_status(:see_other)
    end
  end
end
