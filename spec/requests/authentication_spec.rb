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

  describe "account update" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "renders the edit form" do
      get edit_user_registration_path

      expect(response).to have_http_status(:ok)
    end

    it "updates the name without the password", :aggregate_failures do
      put user_registration_path, params: { user: { first_name: "Changed", last_name: "Name", password: "", password_confirmation: "", current_password: "" } }

      expect(response).to have_http_status(:see_other)
      expect(user.reload.first_name).to eq("Changed")
    end

    it "updates the password when provided", :aggregate_failures do
      put user_registration_path, params: { user: { first_name: "Ada", last_name: "Lovelace", password: "newpassword1", password_confirmation: "newpassword1" } }

      expect(response).to have_http_status(:see_other)
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
