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
