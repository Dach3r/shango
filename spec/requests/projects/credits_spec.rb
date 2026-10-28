require "rails_helper"

RSpec.describe "Credits" do
  describe "GET /credits" do
    it "requires signing in" do
      get credits_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "credits the author of every Omarchy theme with a link to its repository", :aggregate_failures do
      sign_in_with_project

      get credits_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("projects.credits.index.omarchy.title"), I18n.t("components.settings_nav.items.credits"))
      Membership::OMARCHY_CREDITS.each do |credit|
        expect(response.body).to include(%(href="#{credit[:repository]}"), I18n.t("projects.themes.edit.themes.#{credit[:key]}"), credit[:author])
      end
    end

    it "marks themes without a license", :aggregate_failures do
      sign_in_with_project

      get credits_path

      expect(Membership::OMARCHY_CREDITS.pluck(:license)).to include(nil)
      expect(response.body).to include(I18n.t("projects.credits.index.no_license"))
    end
  end
end
