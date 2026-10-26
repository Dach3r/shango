require "rails_helper"

RSpec.describe "Memberships" do
  let!(:context) { sign_in_with_project }
  let(:membership) { context[2] }

  describe "GET /membership/edit" do
    it "renders the settings form" do
      get edit_membership_path

      expect(response.body).to include(I18n.t("projects.memberships.edit.request_open.label"))
    end
  end

  describe "PATCH /membership" do
    it "saves the folder toggle", :aggregate_failures do
      patch membership_path, params: { membership: { folder_toggle: "click", request_open: "double_click" } }

      expect(response).to redirect_to(edit_membership_path)
      expect(membership.reload).to be_folder_toggle_click
      expect(membership).to be_request_open_double_click
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
end
