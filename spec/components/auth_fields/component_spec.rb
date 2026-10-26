require "rails_helper"

RSpec.describe AuthFields::Component, type: :component do
  let(:collection) { create(:collection) }

  def render_fields(record, **options)
    render_inline(described_class.new(scope: "collection", record:, **options))
  end

  it "renders a section per auth type with the selected one", :aggregate_failures do
    collection.update!(auth_type: "bearer", auth_config: { "token" => "abc" })
    render_fields(collection)

    expect(page).to have_css("input[name='collection[auth_type]'][value=bearer]", visible: :all)
    expect(page).to have_css("[data-auth-form-target=section][data-type=none] p", visible: :all)
    expect(page).to have_css("input[name='collection[auth_config][token]']", visible: :all)
    expect(page).to have_no_css("[data-type=inherit]", visible: :all)
  end

  it "offers inherit when inheritable and falls back to the first type", :aggregate_failures do
    folder = create(:folder, collection:, auth_type: "inherit")
    render_fields(folder, inheritable: true)

    expect(page).to have_css("input[name='collection[auth_type]'][value=inherit]", visible: :all)
    expect(page).to have_css("[data-type=inherit] p", visible: :all)
  end

  it "falls back to the first type when the record type is unknown" do
    folder = create(:folder, collection:, auth_type: "inherit")
    render_fields(folder)

    expect(page).to have_css("input[name='collection[auth_type]'][value=none]", visible: :all)
  end

  it "masks stored secrets, keeps variable references and shows defaults", :aggregate_failures do
    collection.update!(auth_type: "bearer", auth_config: { "token" => "real-secret" })
    render_fields(collection)

    expect(page).to have_css("input[name='collection[auth_config][token]'][value='']", visible: :all)
    expect(page).to have_css("input[placeholder='#{I18n.t("workbench.auth.secret_saved")}']", visible: :all)
  end

  it "keeps variable references in secret fields" do
    collection.update!(auth_type: "bearer", auth_config: { "token" => "{{TOKEN}}" })
    render_fields(collection)

    expect(page).to have_css("input[name='collection[auth_config][token]'][value='{{TOKEN}}']", visible: :all)
  end

  it "renders every field type", :aggregate_failures do
    render_fields(collection)

    expect(page).to have_css("textarea", visible: :all)
    expect(page).to have_css("input[type=password]", visible: :all)
    expect(page).to have_css("input[type=text][data-field-name]", visible: :all)
    expect(page).to have_css("[data-show-when]", visible: :all)
  end

  context "with oauth2" do
    it "asks to save first for new records" do
      render_fields(build(:collection, auth_type: "oauth2"))

      expect(page.text(:all)).to include(I18n.t("workbench.oauth2.save_first"))
    end

    it "shows a missing token state", :aggregate_failures do
      collection.update!(auth_type: "oauth2", auth_config: {})
      render_fields(collection)

      expect(page.text(:all)).to include(I18n.t("workbench.oauth2.token_missing"))
      expect(page).to have_css("button[form='oauth2-token-#{collection.id}']", visible: :all)
      expect(page).to have_no_css("button[form='oauth2-clear-#{collection.id}']", visible: :all)
    end

    it "shows the token with its expiry", :aggregate_failures do
      collection.update!(auth_type: "oauth2", auth_config: { "access_token" => "t", "expires_at" => 1.hour.from_now.iso8601 })
      render_fields(collection)

      expect(page.text(:all)).to include(I18n.t("workbench.oauth2.token_present"))
      expect(page).to have_css("button[form='oauth2-clear-#{collection.id}']", visible: :all)
      expect(page.text(:all)).to include("·")
    end

    it "shows the token without an expiry" do
      collection.update!(auth_type: "oauth2", auth_config: { "access_token" => "t" })
      render_fields(collection)

      expect(page.text(:all)).not_to include("·")
    end
  end
end
