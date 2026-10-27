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

  describe "mail content" do
    before { enable_mail }

    let(:user) { create(:user, :confirmed) }

    def reset_mail
      post user_password_path, params: { user: { email: user.email } }
      ActionMailer::Base.deliveries.last
    end

    it "sends the reset link to the account", :aggregate_failures do
      mail = reset_mail

      expect(mail.to).to eq([user.email])
      expect(mail.body.encoded).to include("reset_password_token=")
    end

    it "uses the Spanish subject with the locale cookie", :aggregate_failures do
      cookies[:locale] = "es"

      expect(reset_mail.subject).to eq(I18n.t("devise.mailer.reset_password_instructions.subject", locale: :es))
      expect(reset_mail.subject).not_to eq(I18n.t("devise.mailer.reset_password_instructions.subject", locale: :en))
    end

    it "resets the password with the emailed token only once", :aggregate_failures do
      token = user.send_reset_password_instructions
      params = { user: { reset_password_token: token, password: "brandnew123", password_confirmation: "brandnew123" } }

      put user_password_path, params: params
      expect(user.reload.valid_password?("brandnew123")).to be(true)

      put user_password_path, params: params.deep_merge(user: { password: "another1234", password_confirmation: "another1234" })
      expect(user.reload.valid_password?("another1234")).to be(false)
    end

    it "rejects an invalid reset token", :aggregate_failures do
      put user_password_path, params: { user: { reset_password_token: "bogus", password: "brandnew123", password_confirmation: "brandnew123" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("brandnew123")).to be(false)
    end

    it "rejects an expired reset token", :aggregate_failures do
      token = user.send_reset_password_instructions

      travel_to(User.reset_password_within.from_now + 1.minute) do
        put user_password_path, params: { user: { reset_password_token: token, password: "brandnew123", password_confirmation: "brandnew123" } }
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("brandnew123")).to be(false)
    end

    it "does not confirm with a wrong token", :aggregate_failures do
      unconfirmed = create(:user)
      get user_confirmation_path(confirmation_token: "bogus")

      expect(unconfirmed.reload.confirmed?).to be(false)
    end

    it "sends a confirmation mail with the token on sign up", :aggregate_failures do
      post user_registration_path, params: { user: { first_name: "Grace", last_name: "Hopper", email: "grace@example.com", password: "password123", password_confirmation: "password123" } }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(["grace@example.com"])
      expect(mail.body.encoded).to include("confirmation_token=")
    end
  end
end
