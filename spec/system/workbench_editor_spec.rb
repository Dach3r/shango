require "rails_helper"

RSpec.describe "Workbench editor", :system do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:membership) { create(:membership, :owner, user:, project:) }
  let(:environment) { create(:environment, project:) }
  let!(:variable) { create(:variable, environment:, key: "adminPassword", value: "password") }
  let(:collection) { create(:collection, project:) }
  let!(:api_request) do
    create(:api_request, collection:, name: "Create token", http_method: "POST", url: "{{adminPassword}}/auth", body_type: "json", body: %({"password": "{{adminPassword}}"}))
  end

  before do
    membership.update!(current_environment: environment)
    user.update!(current_membership: membership)
    login_as user, scope: :user
  end

  describe "saving the request" do
    before do
      create(:request_execution, api_request:, user:, http_method: "POST", response_body: %({"token":"abc123"}), response_headers: [])
      visit workbench_request_path(api_request)
    end

    it "keeps the editors, variable highlighting, tabs and response body", :aggregate_failures do
      click_button "Save"

      expect(page).to have_css("#request_form .cm-editor .cm-var", visible: :all)
      expect(page).to have_css("[role=tab][aria-selected=true]", minimum: 2, visible: :all)
      expect(page).to have_css("#response_panel .cm-editor", visible: :all)
    end
  end

  describe "URL preview" do
    before do
      create(:request_execution, api_request:, user:, http_method: "POST", response_body: %({"token":"abc123"}), response_headers: [])
      visit workbench_request_path(api_request)
    end

    it "shows next to the copy button the URL with the environment variables resolved", :aggregate_failures do
      expect(page).to have_css("[data-url-preview-slot]", text: "password/auth")

      find("[role=tab]", text: "Body", match: :first).click
      fill_in_card("{{adminPassword}}", "secret2")

      expect(page).to have_css("[data-url-preview-slot]", text: "secret2/auth")
    end
  end

  describe "editing a variable from its hover card" do
    before { visit workbench_request_path(api_request) }

    it "saves on Enter without submitting the request form and closes the card", :aggregate_failures do
      find("[role=tab]", text: "Body").click
      fill_in_card("{{adminPassword}}", "password123")

      expect(page).to have_no_css(".cm-var-card-input")
      expect(page).to have_current_path(workbench_request_path(api_request))
      expect(variable.reload.value).to eq("password123")
      expect(api_request.reload.body).to include("{{adminPassword}}")
    end

    it "shows the saved value when the card is opened again in the body editor", :aggregate_failures do
      find("[role=tab]", text: "Body").click
      fill_in_card("{{adminPassword}}", "password123")
      hover_variable("{{adminPassword}}")

      expect(page).to have_field(class: "cm-var-card-input", with: "password123")
    end
  end

  def hover_variable(name)
    find("#request_form [data-tabs-target=panel][data-name=body] .cm-var", text: name).hover
  end

  def fill_in_card(name, value)
    hover_variable(name)
    input = find(".cm-var-card-input")
    input.fill_in(with: value)
    input.send_keys(:enter)
  end
end
