require "rails_helper"

RSpec.describe "Cookies" do
  let!(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:membership) { context[2] }
  let(:environment) { create(:environment, project:) }

  describe "GET /cookies" do
    it "lists the cookies of the jar without their values", :aggregate_failures do
      create(:cookie, project:, name: "_session", value: "topsecret", secure: true, http_only: true, expires_at: 1.day.from_now)
      create(:cookie, project:, name: "plain")
      create(:cookie, project:, name: "other_env", environment:)
      create(:cookie, name: "foreign")
      get cookies_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include("_session", "plain", I18n.t("projects.cookies.index.session"), I18n.t("projects.cookies.index.secure"), I18n.t("projects.cookies.index.http_only"))
      expect(response.body).not_to include("topsecret", "other_env", "foreign")
    end

    it "lists the cookies of the selected environment", :aggregate_failures do
      membership.update!(current_environment: environment)
      create(:cookie, project:, name: "scoped", environment:)
      create(:cookie, project:, name: "bare")
      get cookies_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include("scoped", environment.name)
      expect(response.body).not_to include("bare")
    end

    it "hides expired cookies and shows an empty state", :aggregate_failures do
      create(:cookie, project:, name: "stale", expires_at: 1.day.ago)
      get cookies_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include(I18n.t("projects.cookies.index.empty_title"))
      expect(response.body).not_to include("stale")
    end

    it "redirects to the workbench outside the side panel" do
      get cookies_path

      expect(response).to redirect_to(workbench_root_path)
    end
  end

  describe "GET /cookies/new" do
    it "renders the form in the side panel" do
      get new_cookie_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include(I18n.t("projects.cookies.form.new_title"), "cookie[name]")
    end

    it "redirects to the workbench outside the side panel" do
      get new_cookie_path

      expect(response).to redirect_to(workbench_root_path)
    end
  end

  describe "POST /cookies" do
    let(:params) { { cookie: { name: "sid", value: "abc", domain: "API.example.com", path: "/", expires_at: "", host_only: "1", secure: "1", http_only: "0" } } }

    it "adds a cookie to the jar of the selected environment", :aggregate_failures do
      membership.update!(current_environment: environment)

      expect { post cookies_path, params: }.to change(Cookie, :count).by(1)
      expect(response).to redirect_to(cookies_path)
      expect(Cookie.last).to have_attributes(project:, environment:, name: "sid", value: "abc", domain: "api.example.com", secure: true, http_only: false, expires_at: nil)
    end

    it "renders the form again when the cookie is invalid", :aggregate_failures do
      expect { post cookies_path, params: { cookie: { name: "", domain: "x.test" } }, headers: { "Turbo-Frame" => "right_sidebar" } }.not_to change(Cookie, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("cookie[name]")
    end
  end

  describe "GET /cookies/:id/edit" do
    it "shows the value of the cookie in plain text", :aggregate_failures do
      cookie = create(:cookie, project:, name: "_session", value: "topsecret")
      get edit_cookie_path(cookie), headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include("_session", "topsecret")
    end

    it "does not open cookies of other projects" do
      get edit_cookie_path(create(:cookie)), headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /cookies/:id" do
    it "updates the cookie", :aggregate_failures do
      cookie = create(:cookie, project:, value: "old")

      patch cookie_path(cookie), params: { cookie: { value: "new", path: "/v1" } }

      expect(response).to redirect_to(cookies_path)
      expect(cookie.reload).to have_attributes(value: "new", path: "/v1")
    end

    it "renders the form again when the cookie is invalid", :aggregate_failures do
      cookie = create(:cookie, project:)

      patch cookie_path(cookie), params: { cookie: { path: "no_slash" } }, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(cookie.reload.path).to eq("/")
    end

    it "does not touch cookies of other projects", :aggregate_failures do
      foreign = create(:cookie, value: "keep")

      patch cookie_path(foreign), params: { cookie: { value: "hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.value).to eq("keep")
    end
  end

  describe "DELETE /cookies/:id" do
    it "deletes the cookie" do
      cookie = create(:cookie, project:)

      expect { delete cookie_path(cookie) }.to change(Cookie, :count).by(-1)
      expect(response).to redirect_to(cookies_path)
    end

    it "does not touch cookies of other projects", :aggregate_failures do
      foreign = create(:cookie)

      expect { delete cookie_path(foreign) }.not_to change(Cookie, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not touch cookies of other environments", :aggregate_failures do
      other = create(:cookie, project:, environment:)

      expect { delete cookie_path(other) }.not_to change(Cookie, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /cookie_jar" do
    it "clears only the selected jar", :aggregate_failures do
      create_list(:cookie, 2, project:)
      kept = create(:cookie, project:, environment:)

      delete cookie_jar_path

      expect(response).to redirect_to(cookies_path)
      expect(Cookie.all).to contain_exactly(kept)
    end
  end
end
