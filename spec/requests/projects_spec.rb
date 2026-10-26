require "rails_helper"

RSpec.describe "Projects" do
  let(:user) { create(:user) }

  describe "without a project" do
    before { sign_in user }

    it "redirects the root to the new project form" do
      get root_path

      expect(response).to redirect_to(new_project_path)
    end

    it "renders the new form" do
      get new_project_path

      expect(response).to have_http_status(:ok)
    end

    it "creates the project and selects it", :aggregate_failures do
      expect { post projects_path, params: { project: { name: "Acme", icon: "rocket" } } }.to change(Project, :count).by(1)
      expect(response).to redirect_to(root_path)
      expect(user.reload.current_membership.project.name).to eq("Acme")
    end

    it "re-renders when invalid", :aggregate_failures do
      expect { post projects_path, params: { project: { name: "", icon: "rocket" } } }.not_to change(Project, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "with a project" do
    let!(:context) { sign_in_with_project(user) }
    let(:project) { context[1] }

    it "shows the workbench on the root" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    it "lists projects" do
      get projects_path

      expect(response).to have_http_status(:ok)
    end

    it "falls back to the oldest membership when the current one is archived", :aggregate_failures do
      other = create(:membership, user:)
      project.update!(archived_at: Time.current)
      get root_path

      expect(response).to have_http_status(:ok)
      expect(user.reload.current_membership_id).to eq(other.id)
    end
  end

  describe "PATCH /current_project" do
    let!(:context) { sign_in_with_project(user) }
    let(:other_membership) { create(:membership, user:) }

    it "switches the current project", :aggregate_failures do
      patch current_project_path, params: { project_id: other_membership.project_id }

      expect(response).to redirect_to(root_path)
      expect(user.reload.current_membership_id).to eq(other_membership.id)
    end

    it "rejects projects the user does not belong to" do
      foreign = create(:project)
      patch current_project_path, params: { project_id: foreign.id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
