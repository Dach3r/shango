require "rails_helper"

RSpec.describe KeyValueTable::Row::Component, type: :component do
  def render_row(row, variant: :pairs, index: 0, name: "api_request[headers]")
    render_inline(described_class.new(name:, row:, index:, variant:, key_placeholder: "Key", value_placeholder: "Value"))
  end

  context "with the pairs variant" do
    it "renders key, value and description", :aggregate_failures do
      render_row({ "key" => "A", "value" => "1", "description" => "d" })

      expect(page).to have_css("input[name='api_request[headers][0][key]'][value=A]")
      expect(page).to have_css("input[name='api_request[headers][0][value]'][type=text][value='1'][placeholder=Value]")
      expect(page).to have_css("input[name='api_request[headers][0][description]']")
      expect(page).to have_no_css("input[name$='[id]']", visible: :all)
    end

    it "renders disabled rows unchecked" do
      render_row({ "enabled" => false })

      expect(page).to have_no_css("input[type=checkbox][checked]")
    end
  end

  context "with the variables variant" do
    it "masks saved secrets and hints that they are saved", :aggregate_failures do
      render_row({ "id" => "1", "key" => "K", "value" => "s3cret", "secret" => true }, variant: :variables)

      expect(page).to have_css("input[type=password][value='']", visible: :all)
      expect(page).to have_css("input[placeholder='#{I18n.t("components.key_value_table.secret_saved")}']")
      expect(page).to have_css("input[name$='[id]'][value='1']", visible: :all)
      expect(page).to have_css("input[type=checkbox][name$='[secret]'][checked]")
    end

    it "uses the value placeholder for unsaved secrets" do
      render_row({ "key" => "K", "secret" => true }, variant: :variables)

      expect(page).to have_css("input[type=password][placeholder=Value]")
    end

    it "shows plain values for non-secrets" do
      render_row({ "key" => "K", "value" => "v" }, variant: :variables)

      expect(page).to have_css("input[type=text][value=v]")
    end
  end

  context "with the form_data variant" do
    it "renders a text row", :aggregate_failures do
      render_row({ "key" => "k", "value" => "v" }, variant: :form_data, name: "api_request[body_form]")

      expect(page).to have_css("[data-role=text] input[value=v]:not([disabled])")
      expect(page).to have_css("[data-role=file][hidden]", visible: :all)
      expect(page).to have_css("input[name^='api_request[body_uploads]['][disabled]", visible: :all)
    end

    it "offers the file type unless files are not allowed", :aggregate_failures do
      render_row({ "key" => "k" }, variant: :form_data, name: "api_request[body_form]")
      expect(page).to have_css("[data-role=type]", visible: :all)
      expect(page.native.to_html).to include(I18n.t("components.key_value_table.file"))

      render_inline(described_class.new(name: "api_request[body_form]", row: { "key" => "k" }, index: 0, variant: :form_data, key_placeholder: "Key", value_placeholder: "Value", files: false))
      expect(page.native.to_html).not_to include(I18n.t("components.key_value_table.file"))
    end

    it "keeps the file type for a row that already holds a file", :aggregate_failures do
      render_inline(described_class.new(name: "api_request[body_form]", row: { "key" => "f", "type" => "file" }, index: 0, variant: :form_data, key_placeholder: "Key", value_placeholder: "Value", files: false))

      expect(page.native.to_html).to include(I18n.t("components.key_value_table.file"))
    end

    it "renders a file row with its attachment and upload token", :aggregate_failures do
      render_row({ "key" => "f", "type" => "file", "value" => "a.png", "attachment_id" => "9", "upload_token" => "tok" }, variant: :form_data, name: "api_request[body_form]")

      expect(page).to have_css("[data-role=text][hidden]", visible: :all)
      expect(page).to have_css("input[name='api_request[body_uploads][tok]'][type=file]:not([disabled])", visible: :all)
      expect(page).to have_css("input[name$='[attachment_id]'][value='9']", visible: :all)
      expect(page).to have_css("[data-role=file] p", text: "a.png", visible: :all)
    end

    it "omits the file caption when the file has no value" do
      render_row({ "type" => "file", "upload_token" => "tok" }, variant: :form_data, name: "api_request[body_form]")

      expect(page).to have_no_css("[data-role=file] p", visible: :all)
    end

    it "keeps the template token placeholder for new rows" do
      render_row({ "enabled" => true }, variant: :form_data, index: "NEW_INDEX", name: "api_request[body_form]")

      expect(page).to have_css("input[name='api_request[body_uploads][NEW_INDEX]']", visible: :all)
    end

    it "generates a random upload token for rows without one" do
      render_row({ "enabled" => true }, variant: :form_data, name: "api_request[body_form]")

      expect(page).to have_css("input[type=file][name^='api_request[body_uploads][']:not([name$='[NEW_INDEX]'])", visible: :all)
    end
  end
end
