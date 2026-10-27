require "rails_helper"

RSpec.describe "Environments" do
  let!(:context) { sign_in_with_project }
  let(:user) { context[0] }
  let(:project) { context[1] }
  let(:membership) { context[2] }
  let(:environment) { create(:environment, project:) }
  let(:foreign_environment) { create(:environment) }

  describe "GET /environments" do
    it "lists the project's environments" do
      create(:variable, environment:, key: "HOST")
      get environments_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include(environment.name)
    end

    it "marks the active environment and offers to activate the others", :aggregate_failures do
      other = create(:environment, project:)
      membership.update!(current_environment: environment)
      get environments_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include(I18n.t("projects.environments.index.in_use"))
      expect(response.body.scan(%(">#{I18n.t("projects.environments.index.activate")}<)).size).to eq(1)
      expect(response.body).to include(other.name)
    end

    it "redirects to the workbench outside the side panel", :aggregate_failures do
      get environments_path
      expect(response).to redirect_to(workbench_root_path)

      get new_environment_path
      expect(response).to redirect_to(workbench_root_path)

      get edit_environment_path(environment)
      expect(response).to redirect_to(workbench_root_path)
    end
  end

  describe "GET /environments from the side panel" do
    it "wraps the content in the right sidebar frame and skips the app layout", :aggregate_failures do
      get environments_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include('<turbo-frame class="flex flex-1 flex-col" id="right_sidebar">')
      expect(response.body).not_to include("data-controller=\"right-sidebar\"")
    end
  end

  describe "form from the side panel" do
    it "shows a back header with the title", :aggregate_failures do
      get new_environment_path, headers: { "Turbo-Frame" => "right_sidebar" }
      expect(response.body).to include("<h3", I18n.t("projects.environments.new.title"))

      get edit_environment_path(environment), headers: { "Turbo-Frame" => "right_sidebar" }
      expect(response.body).to include(environment.name)
    end
  end

  describe "GET /environments/new" do
    it "renders the form" do
      get new_environment_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /environments" do
    it "creates an environment with variables", :aggregate_failures do
      params = { environment: { name: "Staging", variables_attributes: { "0" => { key: "TOKEN", value: "abc", secret: "1", enabled: "1" } } } }

      expect { post environments_path, params: }.to change(project.environments, :count).by(1)
      expect(response).to redirect_to(environments_path)
    end

    it "re-renders when invalid", :aggregate_failures do
      post environments_path, params: { environment: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /environments/:id/edit" do
    it "renders the form" do
      get edit_environment_path(environment), headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response).to have_http_status(:ok)
    end

    it "does not find environments of other projects" do
      get edit_environment_path(foreign_environment), headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /environments/:id" do
    it "updates the environment", :aggregate_failures do
      patch environment_path(environment), params: { environment: { name: "Renamed" } }

      expect(response).to redirect_to(environments_path)
      expect(environment.reload.name).to eq("Renamed")
    end

    it "re-renders when invalid", :aggregate_failures do
      patch environment_path(environment), params: { environment: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /environments/:id" do
    it "destroys the environment", :aggregate_failures do
      environment
      expect { delete environment_path(environment) }.to change(Environment, :count).by(-1)
      expect(response).to redirect_to(environments_path)
    end
  end

  describe "PATCH /current_environment" do
    it "selects the environment and goes back", :aggregate_failures do
      patch current_environment_path, params: { environment_id: environment.id }, headers: { "HTTP_REFERER" => "http://www.example.com/workbench" }

      expect(response).to redirect_to("http://www.example.com/workbench")
      expect(membership.reload.current_environment).to eq(environment)
    end

    it "clears the selection with a blank id", :aggregate_failures do
      membership.update!(current_environment: environment)
      patch current_environment_path, params: { environment_id: "" }

      expect(response).to redirect_to(root_path)
      expect(membership.reload.current_environment).to be_nil
    end

    it "rejects environments of other projects" do
      patch current_environment_path, params: { environment_id: foreign_environment.id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "authorization and tampering" do
    it "does not update environments of other projects", :aggregate_failures do
      patch environment_path(foreign_environment), params: { environment: { name: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(foreign_environment.reload.name).not_to eq("Hacked")
    end

    it "does not destroy environments of other projects", :aggregate_failures do
      foreign_environment

      expect { delete environment_path(foreign_environment) }.not_to change(Environment, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not touch variables of other projects through nested attributes", :aggregate_failures do
      foreign_variable = create(:variable, value: "keep")

      patch environment_path(environment), params: { environment: { variables_attributes: { "0" => { id: foreign_variable.id, key: foreign_variable.key, value: "hacked" } } } }

      expect(response).to have_http_status(:not_found)
      expect(foreign_variable.reload.value).to eq("keep")
    end

    it "ignores a project id in the params", :aggregate_failures do
      post environments_path, params: { environment: { name: "Staging", project_id: foreign_environment.project_id } }

      expect(Environment.find_by!(name: "Staging").project).to eq(project)
    end

    it "requires authentication", :aggregate_failures do
      sign_out user
      get environments_path, headers: { "Turbo-Frame" => "right_sidebar" }
      expect(response).to redirect_to(new_user_session_path)

      patch current_environment_path, params: { environment_id: environment.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "answers 400 without the environment key" do
      post environments_path

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "names" do
    it "rejects duplicate names ignoring case within a project", :aggregate_failures do
      create(:environment, project:, name: "Staging")

      expect { post environments_path, params: { environment: { name: "STAGING" } } }.not_to change(Environment, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "allows the same name in different projects" do
      create(:environment, name: "Staging")

      expect { post environments_path, params: { environment: { name: "Staging" } } }.to change(project.environments, :count).by(1)
    end

    it "rejects a rename that collides with a sibling" do
      create(:environment, project:, name: "Prod")
      patch environment_path(environment), params: { environment: { name: "prod" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps unicode names" do
      post environments_path, params: { environment: { name: "Producción ✓" } }

      expect(project.environments.pluck(:name)).to include("Producción ✓")
    end
  end

  describe "variables in the form" do
    it "stores secret variables encrypted and never renders their value back", :aggregate_failures do
      post environments_path, params: { environment: { name: "Staging", variables_attributes: { "0" => { key: "TOKEN", value: "s3cr3t-value", secret: "1", enabled: "1" } } } }
      variable = Variable.find_by!(key: "TOKEN")

      expect(variable.value_before_type_cast).not_to include("s3cr3t-value")
      get edit_environment_path(variable.environment), headers: { "Turbo-Frame" => "right_sidebar" }
      get environments_path, headers: { "Turbo-Frame" => "right_sidebar" }
      expect(response.body).not_to include("s3cr3t-value")
    end

    it "does not render a secret value in the edit form" do
      create(:variable, :secret, environment:, key: "TOKEN", value: "s3cr3t-value")
      get edit_environment_path(environment), headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).not_to include("s3cr3t-value")
    end

    it "keeps a secret value when the form submits it blank", :aggregate_failures do
      variable = create(:variable, :secret, environment:, key: "TOKEN", value: "s3cr3t-value")

      patch environment_path(environment), params: { environment: { variables_attributes: { "0" => { id: variable.id, key: "TOKEN", value: "", secret: "1" } } } }

      expect(response).to redirect_to(environments_path)
      expect(variable.reload.value).to eq("s3cr3t-value")
    end

    it "removes a variable marked for destruction" do
      variable = create(:variable, environment:)

      expect { patch environment_path(environment), params: { environment: { variables_attributes: { "0" => { id: variable.id, _destroy: "1" } } } } }.to change(environment.variables, :count).by(-1)
    end

    it "rejects an invalid variable key and keeps the environment unchanged", :aggregate_failures do
      patch environment_path(environment), params: { environment: { name: "Renamed", variables_attributes: { "0" => { key: "bad key", value: "x" } } } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(environment.reload.name).not_to eq("Renamed")
    end

    it "rejects a key that already exists in the environment", :aggregate_failures do
      create(:variable, environment:, key: "HOST")
      patch environment_path(environment), params: { environment: { variables_attributes: { "0" => { key: "HOST", value: "x" } } } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "ignores fully blank rows and rejects rows with a value but no key", :aggregate_failures do
      patch environment_path(environment), params: { environment: { variables_attributes: { "0" => { key: "", value: "" } } } }
      expect(response).to redirect_to(environments_path)

      patch environment_path(environment), params: { environment: { variables_attributes: { "0" => { key: "", value: "x" } } } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "stores very long unicode values", :aggregate_failures do
      value = "ñandú ✓ " * 5_000
      post environments_path, params: { environment: { name: "Big", variables_attributes: { "0" => { key: "BIG", value: } } } }

      expect(Variable.find_by!(key: "BIG").value).to eq(value)
    end
  end

  describe "destroying" do
    it "removes variables and cookies of the environment and clears selections", :aggregate_failures do
      create(:variable, environment:)
      create(:cookie, project:, environment:)
      membership.update!(current_environment: environment)

      delete environment_path(environment)

      expect(Variable.count).to eq(0)
      expect(Cookie.count).to eq(0)
      expect(membership.reload.current_environment_id).to be_nil
      get workbench_root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /current_environment edge cases" do
    it "answers 404 for an id that does not exist" do
      patch current_environment_path, params: { environment_id: SecureRandom.uuid }

      expect(response).to have_http_status(:not_found)
    end

    it "only changes the signed-in user's selection", :aggregate_failures do
      other = create(:membership, project:)
      patch current_environment_path, params: { environment_id: environment.id }

      expect(other.reload.current_environment_id).to be_nil
    end
  end
end
