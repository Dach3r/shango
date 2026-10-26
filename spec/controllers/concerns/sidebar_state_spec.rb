require "rails_helper"

RSpec.describe SidebarState, type: :controller do
  controller(ApplicationController) do
    def index
      render plain: sidebar_collapsed?.to_s
    end
  end

  it "is collapsed when the cookie says so" do
    cookies[:sidebar_collapsed] = "true"
    get :index

    expect(response.body).to eq("true")
  end

  it "is expanded by default" do
    get :index

    expect(response.body).to eq("false")
  end
end
