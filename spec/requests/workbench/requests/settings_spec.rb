require "rails_helper"

RSpec.describe "Workbench request settings" do
  include_context "with workbench project"

  describe "PATCH /workbench/requests/:request_id/settings" do
    it "saves the settings right away", :aggregate_failures do
      patch workbench_request_settings_path(api_request), params: { api_request: { settings: { timeout: "45", verify_ssl: "0" } } }

      expect(response).to have_http_status(:no_content)
      expect(api_request.reload.setting(:timeout)).to eq(45)
      expect(api_request.setting(:verify_ssl)).to be(false)
    end

    it "rejects an invalid request", :aggregate_failures do
      api_request.update_columns(name: "")
      patch workbench_request_settings_path(api_request), params: { api_request: { settings: { timeout: "45" } } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(api_request.reload.setting(:timeout)).not_to eq(45)
    end

    it "does not find requests of other projects" do
      patch workbench_request_settings_path(foreign_request), params: { api_request: { settings: { timeout: "45" } } }

      expect(response).to have_http_status(:not_found)
    end
  end
end
