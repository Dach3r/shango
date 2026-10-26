require "rails_helper"

RSpec.describe CodeEditor::Component, type: :component do
  context "without a name" do
    it "renders a bare textarea inside the controller wrapper", :aggregate_failures do
      render_inline(described_class.new(value: "{}", language: "json", single_line: true, variables: %w[a], data: { foo: "bar" }, class: "extra"))

      expect(page).to have_css("div.code-editor.extra[data-controller=code-editor][data-code-editor-language-value=json][data-foo=bar]")
      expect(page).to have_css("textarea[rows='1'][data-code-editor-target=input]", text: "{}")
      expect(page).to have_css("[data-code-editor-target=mount]")
      expect(page.find("div.code-editor")["data-code-editor-labels-value"]).to include("\"dynamic\":\"Dynamic\"", "\"isoTimestamp\":\"ISO 8601 date\"", "\"missing\":\"Undefined\"")
    end
  end

  context "with a name" do
    it "renders a named textarea", :aggregate_failures do
      render_inline(described_class.new(name: "body", id: "body_field", readonly: true, input_data: { x: "1" }))

      expect(page).to have_css("textarea#body_field[name=body][rows='8'][readonly][data-x='1']")
    end
  end
end
