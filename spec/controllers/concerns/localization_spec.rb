require "rails_helper"

RSpec.describe Localization do
  describe ".supported" do
    it "returns supported locales as strings", :aggregate_failures do
      expect(described_class.supported("es")).to eq("es")
      expect(described_class.supported("pt-BR")).to eq("pt-BR")
      expect(described_class.supported("it")).to be_nil
      expect(described_class.supported(nil)).to be_nil
    end
  end

  describe ".from_cookie" do
    it "falls back to the default locale", :aggregate_failures do
      expect(described_class.from_cookie("es")).to eq(:es)
      expect(described_class.from_cookie("zz")).to eq(:en)
    end
  end

  describe "locale switching", type: :controller do
    controller(ApplicationController) do
      def index
        render plain: I18n.locale.to_s
      end
    end

    it "uses the locale cookie", :aggregate_failures do
      cookies[:locale] = "es"
      get :index

      expect(response.body).to eq("es")
      expect(I18n.locale).to eq(:en)
    end
  end

  describe "edge cases" do
    it "rejects blank, padded and cased variants", :aggregate_failures do
      [nil, "", " es", "ES", "es-CL", ["es"], { es: 1 }].each do |value|
        expect(described_class.supported(value)).to be_nil, value.inspect
      end
    end

    it "falls back to English for a tampered cookie", type: :controller do
      expect(described_class.from_cookie("../../etc/passwd")).to eq(:en)
    end
  end
end
