require "rails_helper"

RSpec.describe "Environment variables" do
  let!(:context) { sign_in_with_project }
  let(:project) { context[1] }
  let(:environment) { create(:environment, project:) }

  describe "PATCH /environments/:environment_id/variables/:id" do
    it "updates the value", :aggregate_failures do
      variable = create(:variable, environment:, value: "old")
      patch environment_variable_path(environment, variable), params: { variable: { value: "new" } }

      expect(response.parsed_body).to eq("set" => true, "value" => "new")
      expect(variable.reload.value).to eq("new")
    end

    it "returns the mask for secrets", :aggregate_failures do
      variable = create(:variable, :secret, environment:, value: "old")
      patch environment_variable_path(environment, variable), params: { variable: { value: "new" } }

      expect(response.parsed_body["value"]).to eq(ApiClient::Masker::MASK)
      expect(variable.reload.value).to eq("new")
    end

    it "keeps a secret when the value is blank" do
      variable = create(:variable, :secret, environment:, value: "old")
      patch environment_variable_path(environment, variable), params: { variable: { value: "" } }

      expect(variable.reload.value).to eq("old")
    end

    it "rejects a failed save" do
      variable = create(:variable, environment:)
      allow_any_instance_of(Variable).to receive(:save).and_return(false)
      patch environment_variable_path(environment, variable), params: { variable: { value: "x" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not find variables of other projects" do
      variable = create(:variable)
      patch environment_variable_path(variable.environment, variable), params: { variable: { value: "x" } }

      expect(response).to have_http_status(:not_found)
    end
  end
end
