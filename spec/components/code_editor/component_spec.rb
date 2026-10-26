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

  context "with a variables url" do
    it "passes it to the controller" do
      render_inline(described_class.new(variables_url: "/environments/1/variables"))

      expect(page).to have_css("div.code-editor[data-code-editor-variables-url-value='/environments/1/variables']")
    end
  end

  context "with responses" do
    it "passes them and the preview url to the controller", :aggregate_failures do
      render_inline(described_class.new(responses: [{ id: "1", name: "Login" }], responses_url: "/workbench/requests/1/response_reference"))

      editor = page.find("div.code-editor")
      expect(JSON.parse(editor["data-code-editor-responses-value"])).to eq([{ "id" => "1", "name" => "Login" }])
      expect(editor["data-code-editor-responses-url-value"]).to eq("/workbench/requests/1/response_reference")
    end
  end

  context "with a name" do
    it "renders a named textarea", :aggregate_failures do
      render_inline(described_class.new(name: "body", id: "body_field", readonly: true, input_data: { x: "1" }))

      expect(page).to have_css(".code-editor.code-editor-readonly textarea#body_field[name=body][rows='8'][readonly][data-x='1']")
    end
  end
end
