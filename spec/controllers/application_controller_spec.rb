require "rails_helper"

RSpec.describe ApplicationController do
  render_views

  controller do
    def index
      render html: "plain-body", layout: true
    end
  end

  it "falls back to the default layout outside devise", :aggregate_failures do
    get :index

    expect(response.body).to include("plain-body")
    expect(response.body).to include("<html")
  end
end
