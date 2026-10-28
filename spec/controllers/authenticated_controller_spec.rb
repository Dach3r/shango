require "rails_helper"

RSpec.describe AuthenticatedController do
  controller do
    skip_before_action :require_project
    skip_after_action :verify_authorized

    def index
      render plain: "ok"
    end
  end

  let(:user) { create(:user) }

  before { sign_in user }

  describe "without any usable membership" do
    it "has no current project or environment", :aggregate_failures do
      get :index

      expect(controller.send(:current_membership)).to be_nil
      expect(controller.send(:current_project)).to be_nil
      expect(controller.send(:current_environment)).to be_nil
    end

    it "clears a stale selection", :aggregate_failures do
      membership = create(:membership, user:, project: create(:project, :archived))
      user.update!(current_membership: membership)
      get :index

      expect(controller.send(:current_membership)).to be_nil
      expect(user.reload.current_membership_id).to be_nil
    end
  end

  describe "with memberships" do
    let!(:zeta) { create(:membership, user:, project: create(:project, name: "Zeta"), created_at: 2.days.ago) }
    let!(:alpha) { create(:membership, user:, project: create(:project, name: "Alpha"), created_at: 1.day.ago) }

    it "uses the selected membership and lists the projects by name", :aggregate_failures do
      user.update!(current_membership: alpha)
      get :index

      expect(controller.send(:current_membership)).to eq(alpha)
      expect(controller.send(:current_project)).to eq(alpha.project)
      expect(controller.send(:available_projects).map(&:name)).to eq(%w[Alpha Zeta])
    end

    it "falls back to the oldest membership and remembers it", :aggregate_failures do
      get :index

      expect(controller.send(:current_membership)).to eq(zeta)
      expect(user.reload.current_membership_id).to eq(zeta.id)
    end

    it "ignores revoked memberships and archived projects", :aggregate_failures do
      create(:membership, :revoked, user:, project: create(:project, name: "Revoked"))
      create(:membership, user:, project: create(:project, :archived, name: "Archived"))
      get :index

      expect(controller.send(:available_projects).map(&:name)).to eq(%w[Alpha Zeta])
    end

    it "resolves the selected environment from the project's environments", :aggregate_failures do
      production = create(:environment, project: alpha.project, name: "Production", position: 2)
      staging = create(:environment, project: alpha.project, name: "Staging", position: 1)
      create(:environment, project: zeta.project)
      user.update!(current_membership: alpha)
      alpha.update!(current_environment: production)
      get :index

      expect(controller.send(:project_environments)).to eq([staging, production])
      expect(controller.send(:current_environment)).to eq(production)
    end

    it "has no current environment until one is selected" do
      get :index

      expect(controller.send(:current_environment)).to be_nil
    end

    it "loads memberships, projects and environments in a fixed number of queries" do
      user.update!(current_membership: alpha)
      create_list(:membership, 3, user:)
      create_list(:environment, 3, project: alpha.project)
      get :index

      queries = count_queries do
        controller.send(:current_project)
        controller.send(:available_projects)
        controller.send(:project_environments)
        controller.send(:current_environment)
      end

      expect(queries).to be <= 2
    end
  end
end
