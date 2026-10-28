require "rails_helper"

RSpec.describe Theming do
  describe ".supported" do
    it "returns known themes only", :aggregate_failures do
      expect(described_class.supported("dark")).to eq("dark")
      expect(described_class.supported("neon")).to be_nil
    end
  end

  describe "#current_theme", type: :controller do
    controller(ApplicationController) do
      def index
        render plain: current_theme
      end
    end

    it "reads the cookie", :aggregate_failures do
      cookies[:theme] = "dark"
      get :index

      expect(response.body).to eq("dark")
    end

    it "defaults to system" do
      get :index

      expect(response.body).to eq("system")
    end
  end

  describe "membership theme", type: :controller do
    controller(AuthenticatedController) do
      skip_after_action :verify_authorized

      def index
        render plain: "#{current_theme}/#{current_palette}"
      end
    end

    it "prefers the saved color scheme and palette over the cookie" do
      sign_in create(:membership, color_scheme: "light", theme: "blue").user
      cookies[:theme] = "dark"
      get :index

      expect(response.body).to eq("light/blue")
    end
  end
end
