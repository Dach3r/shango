require "rails_helper"

RSpec.describe KeyValueTable::Component, type: :component do
  let(:rows) { [{ "key" => "Accept", "value" => "json", "description" => "d" }] }

  it "renders a row per entry plus a template, with default placeholders", :aggregate_failures do
    render_inline(described_class.new(name: "api_request[headers]", rows:))

    expect(page).to have_css("[data-controller=key-value-table]")
    expect(page).to have_css("[data-key-value-table-target=body] input[name='api_request[headers][0][key]'][value=Accept][placeholder='#{I18n.t("components.key_value_table.key")}']")
    expect(page).to have_css("template[data-key-value-table-target=template]", visible: :all)
  end

  it "accepts records and custom placeholders and data", :aggregate_failures do
    environment = create(:environment)
    variable = create(:variable, environment:, key: "HOST", value: "x")
    render_inline(described_class.new(name: "environment[variables]", rows: [variable], variant: :variables,
                                      key_placeholder: "K", value_placeholder: "V", data: { foo: "bar" }))

    expect(page).to have_css("[data-foo=bar]")
    expect(page).to have_css("input[name='environment[variables][0][key]'][value=HOST][placeholder=K]")
    expect(page).to have_css("input[name='environment[variables][0][id]']", visible: :all)
  end

  it "keeps one blank row in pairs tables only", :aggregate_failures do
    render_inline(described_class.new(name: "api_request[headers]", rows: []))
    expect(page).to have_css("[data-always-row=true] [data-key-value-table-target=body] [data-key-value-table-target=row]", count: 1)

    render_inline(described_class.new(name: "environment[variables]", rows: [], variant: :variables))
    expect(page).to have_css("[data-always-row=false] [data-key-value-table-target=body] [data-key-value-table-target=row]", count: 0)
  end
end
