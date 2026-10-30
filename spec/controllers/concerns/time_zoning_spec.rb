require "rails_helper"

RSpec.describe TimeZoning, type: :controller do
  controller(ApplicationController) do
    def index
      render plain: Time.zone.name
    end
  end

  it "uses the signed-in user's time zone and restores the default after the request", :aggregate_failures do
    sign_in create(:user, :confirmed, time_zone: "Santiago")

    get :index

    expect(response.body).to eq("Santiago")
    expect(Time.zone.name).to eq("UTC")
  end

  it "keeps the default zone for guests" do
    get :index

    expect(response.body).to eq("UTC")
  end
end
