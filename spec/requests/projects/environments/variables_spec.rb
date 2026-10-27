require "rails_helper"

RSpec.describe "Environment variables" do
  let!(:context) { sign_in_with_project }
  let(:project) { context[1] }
  let(:environment) { create(:environment, project:) }

  describe "POST /environments/:environment_id/variables" do
    it "creates the variable", :aggregate_failures do
      post environment_variables_path(environment), params: { variable: { key: "locale", value: "es" } }

      variable = environment.variables.find_by!(key: "locale")
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("name" => "locale", "set" => true, "value" => "es", "secret" => false, "url" => environment_variable_path(environment, variable))
    end

    it "rejects an invalid key" do
      post environment_variables_path(environment), params: { variable: { key: "bad key", value: "es" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not find environments of other projects" do
      post environment_variables_path(create(:environment)), params: { variable: { key: "locale", value: "es" } }

      expect(response).to have_http_status(:not_found)
    end
  end

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

  describe "edge cases" do
    it "masks secret values in the response", :aggregate_failures do
      create(:variable, :secret, environment:, key: "TOKEN", value: "old")
      post environment_variables_path(environment), params: { variable: { key: "TOKEN", value: "new-secret" } }

      expect(response.parsed_body).to include("secret" => true, "value" => ApiClient::Masker::MASK)
      expect(response.body).not_to include("new-secret")
    end

    it "overwrites an existing key instead of duplicating it and re-enables it", :aggregate_failures do
      create(:variable, environment:, key: "HOST", value: "old", enabled: false)

      expect { post environment_variables_path(environment), params: { variable: { key: "HOST", value: "new" } } }.not_to change(Variable, :count)
      expect(environment.variables.find_by!(key: "HOST")).to have_attributes(value: "new", enabled: true)
    end

    it "rejects a blank key" do
      post environment_variables_path(environment), params: { variable: { key: "", value: "x" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "stores unicode and very long values", :aggregate_failures do
      value = "ñandú ✓ " * 5_000
      post environment_variables_path(environment), params: { variable: { key: "BIG", value: } }

      expect(response).to have_http_status(:created)
      expect(environment.variables.find_by!(key: "BIG").value).to eq(value)
    end

    it "answers 400 without the variable key when creating" do
      post environment_variables_path(environment)

      expect(response).to have_http_status(:bad_request)
    end

    it "answers 400 without the variable key when updating" do
      patch environment_variable_path(environment, create(:variable, environment:))

      expect(response).to have_http_status(:bad_request)
    end

    it "does not update a variable through another environment of the same project" do
      variable = create(:variable, value: "keep")
      patch environment_variable_path(environment, variable), params: { variable: { value: "x" } }

      expect(response).to have_http_status(:not_found)
      expect(variable.reload.value).to eq("keep")
    end

    it "requires authentication", :aggregate_failures do
      sign_out context[0]
      post environment_variables_path(environment), params: { variable: { key: "A", value: "1" } }

      expect(response).to redirect_to(new_user_session_path)
      expect(Variable.count).to eq(0)
    end
  end
end
