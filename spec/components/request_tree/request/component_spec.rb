require "rails_helper"

RSpec.describe RequestTree::Request::Component, type: :component do
  let(:api_request) { create(:api_request, name: "List", http_method: "POST") }

  it "renders an inactive request", :aggregate_failures do
    render_inline(described_class.new(api_request:))

    expect(page).to have_css("li[data-drag-kind=request] a.text-body:not([aria-current])", text: "List")
    expect(page).to have_text("POST")
  end

  it "highlights the active request" do
    render_inline(described_class.new(api_request:, active: true))

    expect(page).to have_css("a[aria-current=page].font-medium")
  end

  it "makes the name renamable in place", :aggregate_failures do
    render_inline(described_class.new(api_request:))

    expect(page).to have_css("span[data-controller=inline-rename][data-inline-rename-param-value=api_request]", text: "List")
    expect(page).to have_css("[data-inline-rename-url-value='/workbench/requests/#{api_request.id}']")
  end

  it "opens an actions menu with icons on right click", :aggregate_failures do
    render_inline(described_class.new(api_request:))

    expect(page).to have_css("li[data-controller=context-menu][data-action*='contextmenu->context-menu#open']")
    expect(page).to have_css("[data-dropdown-target=menu] button[data-action='context-menu#rename'] svg", visible: :all)
    expect(page).to have_css("form[action='/workbench/requests/#{api_request.id}/duplication'] svg", visible: :all)
    expect(page).to have_css("form[action='/workbench/requests/#{api_request.id}'] button.\\!text-danger svg", visible: :all)
  end

  it "escapes hostile names in the markup and the action labels", :aggregate_failures do
    hostile = create(:api_request, name: "<img src=x onerror=alert(1)>\"'")
    render_inline(described_class.new(api_request: hostile))

    expect(page).not_to have_css("img[src=x]", visible: :all)
    expect(page).to have_css("span[data-controller=inline-rename]", text: "<img src=x onerror=alert(1)>\"'")
    expect(page.native.to_html).not_to include("<img src=x")
  end
end
