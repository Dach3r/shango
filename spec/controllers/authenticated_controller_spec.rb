require "rails_helper"

RSpec.describe AuthenticatedController do
  controller do
    skip_before_action :require_project

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
end
