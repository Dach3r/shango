require "rails_helper"

RSpec.describe "Projects" do
  let(:user) { create(:user) }

  describe "without a project" do
    before { sign_in user }

    it "redirects the workbench to the new project form" do
      get workbench_root_path

      expect(response).to redirect_to(new_project_path)
    end

    it "renders the new form with the mono palette and the theme switcher", :aggregate_failures do
      get new_project_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(data-theme="system" data-palette="mono"))
      expect(response.body).to include(%(data-controller="theme-switcher"))
      expect(response.body).not_to include("</svg>#{I18n.t("projects.new.cancel")}</a>")
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

    it "shows the workbench" do
      get workbench_root_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the new form with the member's theme and no switcher", :aggregate_failures do
      context[2].update!(color_scheme: "light", theme: "green")
      get new_project_path

      expect(response.body).to include(%(data-theme="light" data-palette="green"))
      expect(response.body).not_to include(%(data-controller="theme-switcher"))
    end

    it "offers a cancel link back to the root on the new form" do
      get new_project_path

      expect(response.body).to match(%r{<a [^>]*href="#{root_path}"[^>]*>.*</svg>#{I18n.t("projects.new.cancel")}</a>})
    end

    it "falls back to the oldest membership when the current one is archived", :aggregate_failures do
      other = create(:membership, user:)
      project.update!(archived_at: Time.current)
      get workbench_root_path

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

  describe "creating a project" do
    before { sign_in user }

    it "rejects an icon that does not exist", :aggregate_failures do
      expect { post projects_path, params: { project: { name: "Acme", icon: "not-an-icon" } } }.not_to change(Project, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a whitespace-only name and leaves no membership behind", :aggregate_failures do
      expect { post projects_path, params: { project: { name: "   ", icon: "rocket" } } }.not_to change(Membership, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "makes the creator the only owner and ignores extra attributes", :aggregate_failures do
      post projects_path, params: { project: { name: "Acme", icon: "rocket", archived_at: Time.current, id: SecureRandom.uuid } }

      project = Project.find_by!(name: "Acme")
      expect(project.archived_at).to be_nil
      expect(project.memberships.map { |member| [member.user_id, member.role] }).to eq([[user.id, "owner"]])
    end

    it "answers 400 without the project key" do
      post projects_path

      expect(response).to have_http_status(:bad_request)
    end

    it "allows several projects with the same name" do
      create(:project, name: "Acme")

      expect { post projects_path, params: { project: { name: "Acme", icon: "rocket" } } }.to change(Project, :count).by(1)
    end
  end

  describe "current project selection" do
    let!(:context) { sign_in_with_project(user) }
    let(:project) { context[1] }
    let(:membership) { context[2] }

    it "ignores a current membership that belongs to another user", :aggregate_failures do
      foreign = create(:membership)
      user.update!(current_membership_id: foreign.id)
      get workbench_root_path

      expect(response).to have_http_status(:ok)
      expect(user.reload.current_membership_id).to eq(membership.id)
    end

    it "ignores a revoked current membership" do
      create(:membership, :owner, project:)
      membership.revoke!
      get workbench_root_path

      expect(response).to redirect_to(new_project_path)
    end

    it "rejects revoked memberships when switching", :aggregate_failures do
      other = create(:membership, :revoked, user:)
      patch current_project_path, params: { project_id: other.project_id }

      expect(response).to have_http_status(:not_found)
      expect(user.reload.current_membership_id).to eq(membership.id)
    end

    it "rejects archived projects when switching" do
      other = create(:membership, user:, project: create(:project, :archived))
      patch current_project_path, params: { project_id: other.project_id }

      expect(response).to have_http_status(:not_found)
    end

    it "answers 400 without a project id" do
      patch current_project_path

      expect(response).to have_http_status(:bad_request)
    end

    it "does not switch for guests" do
      sign_out user
      patch current_project_path, params: { project_id: project.id }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "does not show data of the previous project after switching", :aggregate_failures do
      create(:environment, project:, name: "OnlyInFirst")
      other = create(:membership, user:)
      patch current_project_path, params: { project_id: other.project_id }
      get environments_path, headers: { "Turbo-Frame" => "right_sidebar" }

      expect(response.body).not_to include("OnlyInFirst")
    end
  end
end
