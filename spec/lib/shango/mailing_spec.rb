require "rails_helper"

RSpec.describe Shango::Mailing do
  def env(values)
    stub_const("ENV", ENV.to_h.merge(values))
  end

  describe ".enabled?" do
    it "is off without SMTP" do
      expect(described_class.enabled?).to be(false)
    end

    it "is on with an SMTP address" do
      env("SHANGO_SMTP_ADDRESS" => "smtp.example.com")

      expect(described_class.enabled?).to be(true)
    end
  end

  describe ".confirmation_required?" do
    it "needs SMTP" do
      expect(described_class.confirmation_required?).to be(false)
    end

    it "is on by default once SMTP is configured" do
      env("SHANGO_SMTP_ADDRESS" => "smtp.example.com")

      expect(described_class.confirmation_required?).to be(true)
    end

    it "can be opted out" do
      env("SHANGO_SMTP_ADDRESS" => "smtp.example.com", "SHANGO_REQUIRE_EMAIL_CONFIRMATION" => "false")

      expect(described_class.confirmation_required?).to be(false)
    end
  end

  describe ".smtp_settings" do
    it "is nil without SMTP" do
      expect(described_class.smtp_settings).to be_nil
    end

    it "builds the settings from the environment" do
      env("SHANGO_SMTP_ADDRESS" => "smtp.example.com", "SHANGO_SMTP_PORT" => "2525", "SHANGO_SMTP_USERNAME" => "me", "SHANGO_SMTP_PASSWORD" => "pw", "SHANGO_SMTP_STARTTLS" => "false")

      expect(described_class.smtp_settings).to eq(address: "smtp.example.com", port: 2525, user_name: "me", password: "pw", authentication: :plain, enable_starttls_auto: false)
    end
  end

  describe ".sender and .url_options" do
    it "have defaults", :aggregate_failures do
      expect(described_class.sender).to eq("shango@localhost")
      expect(described_class.url_options).to eq(host: "localhost", protocol: "https")
    end

    it "come from the environment", :aggregate_failures do
      env("SHANGO_MAIL_FROM" => "hi@shango.dev", "SHANGO_HOST" => "shango.dev", "SHANGO_PROTOCOL" => "http")

      expect(described_class.sender).to eq("hi@shango.dev")
      expect(described_class.url_options).to eq(host: "shango.dev", protocol: "http")
    end
  end
end
