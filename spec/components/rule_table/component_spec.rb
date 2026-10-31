require "rails_helper"

RSpec.describe RuleTable::Component, type: :component do
  def render_table(kind:, rows: [])
    render_inline(described_class.new(kind:, name: "api_request[#{kind}s]", rows:, add_label: "Add one"))
  end

  describe "assertions" do
    it "renders a row per assertion with its source, target, operator and expected value", :aggregate_failures do
      render_table(kind: :assertion, rows: [{ "id" => "abcd1234", "enabled" => true, "source" => "json", "target" => "$.id", "operator" => "equals", "expected" => "1" }])

      expect(page).to have_css("[data-controller=rule-table][data-rule-table-kind-value=assertion]")
      expect(page).to have_css("select[name='api_request[assertions][0][source]'] option[selected][value=json]")
      expect(page).to have_css("select[name='api_request[assertions][0][operator]'] option[selected][value=equals]")
      expect(page).to have_field("api_request[assertions][0][target]", with: "$.id")
      expect(page).to have_field("api_request[assertions][0][expected]", with: "1")
      expect(page).to have_css("input[type=hidden][name='api_request[assertions][0][id]'][value=abcd1234]", visible: :all)
    end

    it "shows only the operators of the source and hides what the choice does not need", :aggregate_failures do
      render_table(kind: :assertion, rows: [{ "source" => "status", "operator" => "in_range", "expected" => "200-299" }])

      expect(page).to have_css("select[name='api_request[assertions][0][operator]'] option", count: 5)
      expect(page).to have_css("input[data-role=target][hidden][disabled]", visible: :all)
    end

    it "hides the expected value for operators without one" do
      render_table(kind: :assertion, rows: [{ "source" => "json", "target" => "$.a", "operator" => "exists" }])

      expect(page).to have_css("input[data-role=expected][hidden][disabled]", visible: :all)
    end

    it "keeps a blank row and a template for new ones", :aggregate_failures do
      render_table(kind: :assertion)

      expect(page).to have_css("[data-rule-table-target=row]", count: 1)
      expect(page).to have_css("template[data-rule-table-target=template]", visible: :all)
      expect(rendered_content).to include("NEW_INDEX")
      expect(page).to have_button("Add one")
    end
  end

  describe "extractors" do
    it "renders the variable and secret fields", :aggregate_failures do
      render_table(kind: :extractor, rows: [{ "source" => "header", "target" => "x-id", "variable" => "rid", "secret" => true, "enabled" => false }])

      expect(page).to have_css("select[name='api_request[extractors][0][source]'] option", count: 4)
      expect(page).to have_field("api_request[extractors][0][variable]", with: "rid")
      expect(page).to have_field("api_request[extractors][0][target]", with: "x-id")
      expect(page).to have_css("input[type=checkbox][name='api_request[extractors][0][secret]'][checked]", visible: :all)
      expect(page).to have_css("input[type=checkbox][name='api_request[extractors][0][enabled]']:not([checked])", visible: :all)
      expect(page).to have_no_css("select[name*='operator']")
    end
  end
end
