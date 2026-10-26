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
      get environments_path

      expect(response.body).to include(environment.name)
    end
  end

  describe "GET /environments from the side panel" do
    it "wraps the content in the right sidebar frame and skips the app layout", :aggregate_failures do
      get environments_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).to include('<turbo-frame id="right_sidebar">')
      expect(response.body).not_to include("data-controller=\"drawer sidebar right-sidebar\"")
    end
  end

  describe "GET /environments/new" do
    it "renders the form" do
      get new_environment_path

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
      get edit_environment_path(environment)

      expect(response).to have_http_status(:ok)
    end

    it "does not find environments of other projects" do
      get edit_environment_path(foreign_environment)

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
end
