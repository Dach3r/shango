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

    it "wires the profile form to the unsaved changes bar", :aggregate_failures do
      get edit_user_registration_path

      expect(response.body).to include('data-controller="dirty-form"')
      expect(response.body).to include(I18n.t("settings.save_bar.unsaved"))
    end

    it "renders the preferences tab with the language switcher", :aggregate_failures do
      get edit_user_registration_path(tab: "preferences")

      expect(response.body).to include(I18n.t("devise.registrations.edit.preferences.locale.label"))
      expect(response.body).not_to include(%(name="user[email]"))
    end

    it "renders the security tab without the cancel account action", :aggregate_failures do
      get edit_user_registration_path(tab: "security")

      expect(response.body).to include(%(name="user[password]"))
      expect(response.body).not_to include(%(name="user[email]"))
      expect(response.body).not_to include(%(data-turbo-confirm="#{I18n.t("devise.registrations.edit.confirm")}"))
    end

    it "renders the cancel account tab with only the cancel action", :aggregate_failures do
      get edit_user_registration_path(tab: "delete_account")

      expect(response.body).to include(%(data-turbo-confirm="#{I18n.t("devise.registrations.edit.confirm")}"))
      expect(response.body).not_to include(%(name="user[password]"))
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

  describe "cancel account" do
    let(:user) { create(:user) }

    before { sign_in_with_project(user) }

    it "deletes the account with the right password and signs out", :aggregate_failures do
      expect { delete user_registration_path, params: { current_password: "password123" } }.to change(User, :count).by(-1)
      expect(response).to redirect_to(new_user_session_path)

      get new_project_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "keeps the account with a wrong password", :aggregate_failures do
      expect { delete user_registration_path, params: { current_password: "wrong" } }.not_to change(User, :count)
      expect(response).to redirect_to(edit_user_registration_path(tab: "delete_account"))
      expect(flash[:alert]).to eq(I18n.t("devise.registrations.destroy.wrong_password"))
    end

    it "keeps the account without a password" do
      expect { delete user_registration_path }.not_to change(User, :count)
    end

    it "blocks leaving a shared project without an owner", :aggregate_failures do
      project = user.memberships.first.project
      user.memberships.first.update!(role: "owner")
      create(:membership, project:)

      expect { delete user_registration_path, params: { current_password: "password123" } }.not_to change(User, :count)
      expect(flash[:alert]).to eq(I18n.t("devise.registrations.destroy.sole_owner", projects: project.name))
    end

    it "asks for the current password on the cancel tab" do
      get edit_user_registration_path(tab: "delete_account")

      expect(response.body).to include(%(name="current_password"))
    end
  end

  describe "sign up edge cases" do
    def sign_up(overrides = {})
      post user_registration_path, params: { user: user_params.merge(overrides) }
    end

    it "rejects a duplicate email ignoring case and surrounding spaces", :aggregate_failures do
      create(:user, email: "grace@example.com")

      expect { sign_up(email: " GRACE@Example.com ") }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "stores the email stripped and downcased" do
      sign_up(email: "  Grace.H@Example.COM  ")

      expect(User.last.email).to eq("grace.h@example.com")
    end

    it "rejects short, long and mismatched passwords", :aggregate_failures do
      expect { sign_up(password: "short", password_confirmation: "short") }.not_to change(User, :count)
      expect { sign_up(password: "a" * 129, password_confirmation: "a" * 129) }.not_to change(User, :count)
      expect { sign_up(password_confirmation: "different123") }.not_to change(User, :count)
    end

    it "rejects blank, whitespace-only and malformed values", :aggregate_failures do
      [{ first_name: "   " }, { last_name: "" }, { email: "" }, { email: "not-an-email" }].each do |overrides|
        expect { sign_up(overrides) }.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it "does not mass assign protected attributes", :aggregate_failures do
      sign_up(confirmed_at: 1.day.ago, current_membership_id: SecureRandom.uuid, failed_attempts: 5, locked_at: Time.current)

      expect(User.last).to have_attributes(current_membership_id: nil, failed_attempts: 0, locked_at: nil)
    end

    it "accepts unicode names" do
      sign_up(first_name: "Ñandú", last_name: "Müller")

      expect(User.last.initials).to eq("ÑM")
    end

    it "does not let a signed-in user register again", :aggregate_failures do
      sign_in create(:user)

      expect { sign_up }.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end

    it "does not reveal the password in the re-rendered form" do
      sign_up(first_name: "", password: "password123-visible")

      expect(response.body).not_to include("password123-visible")
    end
  end

  describe "sign in edge cases" do
    let!(:user) { create(:user, email: "grace@example.com") }

    it "signs in ignoring email case and spaces", :aggregate_failures do
      post user_session_path, params: { user: { email: " GRACE@example.com ", password: "password123" } }

      expect(response).to redirect_to(root_path)
    end

    it "gives the same answer for a wrong password and an unknown email", :aggregate_failures do
      post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }
      known = flash[:alert]
      post user_session_path, params: { user: { email: "ghost@example.com", password: "wrong-password" } }

      expect(flash[:alert]).to eq(known)
    end

    it "rejects a blank password" do
      post user_session_path, params: { user: { email: user.email, password: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "account update edge cases" do
    let!(:user) { sign_in_with_project[0] }

    it "rejects an email that belongs to another user", :aggregate_failures do
      create(:user, email: "taken@example.com")
      put user_registration_path, params: { user: { email: "TAKEN@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.email).not_to eq("taken@example.com")
    end

    it "rejects a new password without confirmation", :aggregate_failures do
      put user_registration_path(tab: "security"), params: { user: { password: "newpassword1" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("newpassword1")).to be(false)
    end

    it "rejects a weak new password", :aggregate_failures do
      put user_registration_path(tab: "security"), params: { user: { password: "short", password_confirmation: "short" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be(true)
    end

    it "does not need the current password to change the profile" do
      put user_registration_path, params: { user: { first_name: "Changed", current_password: "wrong" } }

      expect(user.reload.first_name).to eq("Changed")
    end

    it "does not mass assign protected attributes", :aggregate_failures do
      other = create(:membership)
      put user_registration_path, params: { user: { first_name: "Changed", current_membership_id: other.id, confirmed_at: "", failed_attempts: 9 } }

      expect(user.reload).to have_attributes(failed_attempts: 0)
      expect(user.current_membership_id).not_to eq(other.id)
    end

    it "keeps the tab from the query after a failed update" do
      put user_registration_path(tab: "security"), params: { user: { password: "x", password_confirmation: "x" } }

      expect(response.body).to include(%(name="user[password]"))
    end
  end
end
