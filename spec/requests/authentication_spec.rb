require "rails_helper"

RSpec.describe "Authentication" do
  let(:user_params) do
    { first_name: "Grace", last_name: "Hopper", email: "grace@example.com", password: "password123", password_confirmation: "password123" }
  end

  describe "guests" do
    it "renders the sign in page on the root" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    it "redirects protected pages to sign in" do
      get new_project_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the sign in page" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "failure app" do
    it "localizes the failure with the locale cookie", :aggregate_failures do
      cookies[:locale] = "es"
      post user_session_path, params: { user: { email: "nobody@example.com", password: "wrong" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('lang="es"')
    end

    it "falls back to the default locale without cookie" do
      post user_session_path, params: { user: { email: "nobody@example.com", password: "wrong" } }

      expect(response.body).to include('lang="en"')
    end
  end

  describe "sign up" do
    it "renders the form" do
      get new_user_registration_path

      expect(response).to have_http_status(:ok)
    end

    it "creates the user and sends them to create a project", :aggregate_failures do
      expect { post user_registration_path, params: { user: user_params } }.to change(User, :count).by(1)
      expect(response).to redirect_to(new_project_path)
    end

    it "re-renders on invalid data" do
      post user_registration_path, params: { user: user_params.merge(first_name: "") }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "members" do
    it "redirects the root to the workbench" do
      sign_in create(:user)
      get root_path

      expect(response).to redirect_to(workbench_root_path)
    end
  end

  describe "account update" do
    let!(:user) { sign_in_with_project[0] }

    it "serves the account settings at /users/settings" do
      expect(edit_user_registration_path).to eq("/users/settings")
    end

    it "renders the profile tab by default", :aggregate_failures do
      get edit_user_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(name="user[email]"))
      expect(response.body).to include(I18n.t("components.settings_nav.items.sidebar"))
    end

    it "renders the preferences tab with the theme and language switchers", :aggregate_failures do
      get edit_user_registration_path(tab: "preferences")

      expect(response.body).to include(I18n.t("devise.registrations.edit.preferences.theme.label"))
      expect(response.body).to include(I18n.t("devise.registrations.edit.preferences.locale.label"))
      expect(response.body).not_to include(%(name="user[email]"))
    end

    it "renders the security tab", :aggregate_failures do
      get edit_user_registration_path(tab: "security")

      expect(response.body).to include(I18n.t("devise.registrations.edit.cancel_account"))
      expect(response.body).not_to include(%(name="user[email]"))
    end

    it "falls back to the profile tab on an unknown tab" do
      get edit_user_registration_path(tab: "nope")

      expect(response.body).to include(%(name="user[email]"))
    end

    it "sends users without a project to create one" do
      sign_in create(:user)

      get edit_user_registration_path

      expect(response).to redirect_to(new_project_path)
    end

    it "updates name and email without the password", :aggregate_failures do
      put user_registration_path, params: { user: { first_name: "Changed", last_name: "Name", email: "changed@example.com", password: "", password_confirmation: "" } }

      expect(response).to redirect_to(edit_user_registration_path(tab: "profile"))
      expect(user.reload).to have_attributes(first_name: "Changed", email: "changed@example.com")
    end

    it "re-renders the profile when invalid", :aggregate_failures do
      put user_registration_path, params: { user: { first_name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.first_name).not_to be_blank
    end

    it "updates the password from the security tab", :aggregate_failures do
      put user_registration_path(tab: "security"), params: { user: { password: "newpassword1", password_confirmation: "newpassword1" } }

      expect(response).to redirect_to(edit_user_registration_path(tab: "security"))
      expect(user.reload.valid_password?("newpassword1")).to be(true)
    end
  end

  describe "sign out" do
    it "lands on sign in" do
      sign_in create(:user)
      delete destroy_user_session_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
