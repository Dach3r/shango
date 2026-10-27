require "rails_helper"

RSpec.describe "Memberships" do
  let!(:context) { sign_in_with_project }
  let(:membership) { context[2] }

  describe "GET /membership/settings" do
    it "renders the settings form with the settings navigation", :aggregate_failures do
      get edit_membership_path

      expect(response.body).to include(I18n.t("projects.memberships.edit.request_open.label"))
      expect(response.body).to include(I18n.t("components.settings_nav.items.sidebar"))
    end
  end

  describe "PATCH /membership" do
    it "saves the folder toggle", :aggregate_failures do
      patch membership_path, params: { membership: { folder_toggle: "click", request_open: "double_click" } }

      expect(response).to redirect_to(edit_membership_path)
      expect(membership.reload).to be_folder_toggle_click
      expect(membership).to be_request_open_double_click
    end

    it "saves the collapse nested folders preference" do
      patch membership_path, params: { membership: { collapse_nested_folders: "0" } }

      expect(membership.reload.collapse_nested_folders).to be(false)
    end

    it "re-renders when invalid", :aggregate_failures do
      allow_any_instance_of(Membership).to receive(:update).and_return(false) # rubocop:disable RSpec/AnyInstance

      patch membership_path, params: { membership: { folder_toggle: "click" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "only changes the signed-in user's membership" do
      other = create(:membership)

      expect { patch membership_path, params: { membership: { folder_toggle: "click" } } }.not_to(change { other.reload.folder_toggle })
    end
  end

  describe "tampered params" do
    it "rejects unknown values without raising", :aggregate_failures do
      patch membership_path, params: { membership: { folder_toggle: "triple_click" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(membership.reload).to be_folder_toggle_double_click
    end

    it "does not let a member escalate their role or move to another project", :aggregate_failures do
      membership.update!(role: "member")
      foreign_project = create(:project)

      patch membership_path, params: { membership: { folder_toggle: "click", role: "owner", project_id: foreign_project.id, revoked_at: "" } }

      expect(membership.reload).to have_attributes(role: "member", project_id: context[1].id)
    end

    it "does not accept a current environment of another project" do
      patch membership_path, params: { membership: { folder_toggle: "click", current_environment_id: create(:environment).id } }

      expect(membership.reload.current_environment_id).to be_nil
    end
  end
end
