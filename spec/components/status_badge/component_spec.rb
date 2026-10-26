require "rails_helper"

RSpec.describe StatusBadge::Component, type: :component do
  it "renders the status and text with the success tone", :aggregate_failures do
    render_inline(described_class.new(execution: build(:request_execution, status: 200, status_text: "OK")))

    expect(page).to have_css("span.text-emerald-700", text: "200 OK")
  end

  it "renders only the status without text" do
    render_inline(described_class.new(execution: build(:request_execution, status: 404, status_text: nil)))

    expect(page).to have_css("span.text-amber-700", text: /\A404\z/)
  end

  it "renders a server error tone" do
    render_inline(described_class.new(execution: build(:request_execution, status: 500)))

    expect(page).to have_css("span.text-red-700", text: "500")
  end

  it "renders the error label for failed executions" do
    render_inline(described_class.new(execution: build(:request_execution, status: nil, error_kind: "timeout")))

    expect(page).to have_css("span.text-red-700", text: I18n.t("workbench.executions.error"))
  end
end
