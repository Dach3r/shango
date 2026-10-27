require "rails_helper"

RSpec.describe "Accounts" do
  describe "GET /account" do
    it "renders the user details, settings and sign out", :aggregate_failures do
      user = sign_in_with_project.first

      get account_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include(user.full_name)
      expect(response.body).to include(user.email)
      expect(response.body).to include(I18n.t("components.user_menu.settings"))
      expect(response.body).to include(I18n.t("components.user_menu.sign_out"))
    end

    it "redirects to the workbench outside the side panel" do
      sign_in_with_project

      get account_path

      expect(response).to redirect_to(workbench_root_path)
    end

    it "redirects guests to sign in" do
      get account_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
