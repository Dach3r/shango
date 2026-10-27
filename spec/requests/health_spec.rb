require "rails_helper"

RSpec.describe "Health" do
  describe "GET /ready" do
    it "is ok when the database answers" do
      get "/ready"

      expect(response).to have_http_status(:ok)
    end

    it "is unavailable when the database fails" do
      allow(ActiveRecord::Base.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionNotEstablished)
      get "/ready"

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
