require "rails_helper"

RSpec.describe "Account security" do
  include ActiveSupport::Testing::TimeHelpers

  let(:mail_env) { { "SHANGO_SMTP_ADDRESS" => "smtp.example.com" } }

  def enable_mail(extra = {})
    stub_const("ENV", ENV.to_h.merge(mail_env, extra))
  end

  describe "without SMTP" do
    it "hides the password reset link on sign in", :aggregate_failures do
      get new_user_session_path

      expect(response.body).not_to include(new_user_password_path)
    end

    it "turns away password reset and confirmation screens", :aggregate_failures do
      [new_user_password_path, new_user_confirmation_path].each do |path|
        get path

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t("mailing.disabled"))
      end
    end

    it "lets new accounts sign in without confirming", :aggregate_failures do
      post user_registration_path, params: { user: { first_name: "Grace", last_name: "Hopper", email: "grace@example.com", password: "password123", password_confirmation: "password123" } }

      expect(response).to redirect_to(new_project_path)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "with SMTP" do
    before { enable_mail }

    it "shows the password reset link", :aggregate_failures do
      get new_user_session_path

      expect(response.body).to include(new_user_password_path)
    end

    it "serves the reset screen and sends instructions", :aggregate_failures do
      user = create(:user, :confirmed)
      get new_user_password_path
      post user_password_path, params: { user: { email: user.email } }

      expect(response).to have_http_status(:see_other)
      expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
    end

    it "answers the same for unknown emails (paranoid mode)", :aggregate_failures do
      post user_password_path, params: { user: { email: "ghost@example.com" } }

      expect(response).to have_http_status(:see_other)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "requires confirmation before signing in", :aggregate_failures do
      post user_registration_path, params: { user: { first_name: "Grace", last_name: "Hopper", email: "grace@example.com", password: "password123", password_confirmation: "password123" } }

      expect(response).to redirect_to(root_path)
      expect(ActionMailer::Base.deliveries.last.subject).to be_present
      post user_session_path, params: { user: { email: "grace@example.com", password: "password123" } }
      expect(response).not_to redirect_to(new_project_path)
    end

    it "shows the resend confirmation link", :aggregate_failures do
      get new_user_session_path

      expect(response.body).to include(new_user_confirmation_path)
    end

    it "signs in after confirming", :aggregate_failures do
      user = create(:user)
      get user_confirmation_path(confirmation_token: user.confirmation_token)

      expect(user.reload.confirmed?).to be(true)
    end

    it "does not enforce confirmation when the operator opts out" do
      enable_mail("SHANGO_REQUIRE_EMAIL_CONFIRMATION" => "false")
      post user_registration_path, params: { user: { first_name: "Grace", last_name: "Hopper", email: "grace@example.com", password: "password123", password_confirmation: "password123" } }

      expect(response).to redirect_to(new_project_path)
    end
  end

  describe "lockout" do
    let!(:user) { create(:user) }

    it "locks the account after the maximum failed attempts", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_SIGN_IN" => "1000/60"))
      User.maximum_attempts.times { post user_session_path, params: { user: { email: user.email, password: "wrong-password" } } }
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect(user.reload.access_locked?).to be(true)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "session timeout" do
    it "signs idle users out" do
      sign_in_with_project
      get workbench_root_path
      travel_to(User.timeout_in.from_now + 1.minute) do
        get workbench_root_path
        follow_redirect!
      end

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
