require "rails_helper"

RSpec.describe "Themes" do
  let!(:context) { sign_in_with_project }
  let(:membership) { context[2] }

  describe "GET /theme/settings" do
    it "renders every theme with the settings navigation", :aggregate_failures do
      get edit_theme_path

      expect(response.body).to include(I18n.t("projects.themes.edit.color_scheme.label"))
      expect(response.body).to include(I18n.t("components.settings_nav.items.themes"))
      Membership::THEMES.each_key { |theme| expect(response.body).to include(%(data-palette="#{theme}")) }
    end

    it "splits accent-only themes from full styles into tabs", :aggregate_failures do
      get edit_theme_path

      expect(response.body).to include(I18n.t("projects.themes.edit.groups.accents"), I18n.t("projects.themes.edit.groups.styles"))
      expect(response.body).to include(%(data-tabs-active-value="accents"))
      expect(Membership::ACCENT_THEMES & Membership::STYLE_THEMES).to be_empty
    end

    it "opens the tab of the saved theme" do
      membership.update!(theme: "nord")

      get edit_theme_path

      expect(response.body).to include(%(data-tabs-active-value="styles"))
    end
  end

  describe "Omarchy themes" do
    it "lists them in their own tab and opens it for a saved one", :aggregate_failures do
      membership.update!(theme: "vulkanite")

      get edit_theme_path

      expect(response.body).to include(I18n.t("projects.themes.edit.groups.omarchy"), %(data-tabs-active-value="omarchy"))
      expect(response.body).to include(%(data-scheme="dark"), %(data-scheme="light"))
    end

    it "disables the color scheme picker while one is selected" do
      membership.update!(theme: "vulkanite")

      get edit_theme_path

      expect(response.body.scan(/<input[^>]*name="membership\[color_scheme\]"[^>]*>/)).to all(include("disabled"))
    end

    it "keeps the color scheme picker enabled for other themes" do
      get edit_theme_path

      expect(response.body.scan(/<input[^>]*name="membership\[color_scheme\]"[^>]*>/)).to all(satisfy { |input| input.exclude?("disabled") })
    end

    it "pins the color scheme of the theme, whatever the member chose", :aggregate_failures do
      membership.update!(color_scheme: "light", theme: "vulkanite")
      get edit_theme_path
      expect(response.body).to include(%(data-theme="dark" data-palette="vulkanite"))

      membership.update!(color_scheme: "dark", theme: "venice_from_above")
      get edit_theme_path
      expect(response.body).to include(%(data-theme="light" data-palette="venice_from_above"))
    end

    it "defines every palette in the stylesheet and the database check", :aggregate_failures do
      css = Rails.root.join("app/assets/tailwind/application.css").read
      constraint = ActiveRecord::Base.connection.check_constraints(:memberships).find { |c| c.name == "memberships_theme_check" }.expression

      Membership::OMARCHY_THEMES.each do |theme|
        expect(css).to include(%([data-palette="#{theme}"]))
        expect(constraint).to include("'#{theme}'")
      end
    end

    it "has a credit with author and repository for each", :aggregate_failures do
      expect(Membership::OMARCHY_CREDITS.size).to eq(Membership::OMARCHY_THEMES.size)
      expect(Membership::OMARCHY_CREDITS).to all(include(:author, :repository, :scheme))
      expect(Membership::OMARCHY_SCHEMES.values.uniq).to match_array(%w[dark light])
    end
  end

  describe "PATCH /theme" do
    it "saves the color scheme and theme", :aggregate_failures do
      patch theme_path, params: { membership: { color_scheme: "dark", theme: "ocean" } }

      expect(response).to redirect_to(edit_theme_path)
      expect(membership.reload).to be_color_scheme_dark
      expect(membership).to be_theme_ocean
    end

    it "re-renders when invalid", :aggregate_failures do
      allow_any_instance_of(Membership).to receive(:update).and_return(false) # rubocop:disable RSpec/AnyInstance

      patch theme_path, params: { membership: { theme: "blue" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "only changes the signed-in user's membership" do
      other = create(:membership)

      expect { patch theme_path, params: { membership: { theme: "red" } } }.not_to(change { other.reload.theme })
    end
  end

  describe "applying the theme" do
    it "renders the workspace with the saved color scheme and palette" do
      membership.update!(color_scheme: "light", theme: "green")

      get edit_theme_path

      expect(response.body).to include(%(data-theme="light" data-palette="green"))
    end
  end

  describe "tampered params" do
    it "rejects unknown values without raising", :aggregate_failures do
      patch theme_path, params: { membership: { color_scheme: "neon", theme: "ocean" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(membership.reload).to be_color_scheme_system
      expect(membership).to be_theme_default
    end

    it "ignores attributes that are not theme settings", :aggregate_failures do
      patch theme_path, params: { membership: { theme: "red", role: "owner", user_id: create(:user).id } }

      expect(response).to redirect_to(edit_theme_path)
      expect(membership.reload).to have_attributes(theme: "red", user_id: context[0].id)
    end

    it "answers 400 without the membership key" do
      patch theme_path

      expect(response).to have_http_status(:bad_request)
    end
  end
end
