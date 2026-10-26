require "rails_helper"

RSpec.describe LocalizedFailureApp, type: :request do
  let(:user) { create(:user) }

  it "renders authentication failures in the cookie locale", :aggregate_failures do
    cookies[:locale] = "es"
    post user_session_path, params: { user: { email: user.email, password: "wrong" } }

    expect(flash[:alert]).to eq(I18n.t("devise.failure.invalid", authentication_keys: "Email", locale: :es))
    expect(I18n.locale).to eq(:en)
  end
end
