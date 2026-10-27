require "rails_helper"

RSpec.describe Select::Component, type: :component do
  let(:options) { [%w[One 1], %w[Two 2]] }

  it "selects the matching option", :aggregate_failures do
    render_inline(described_class.new(name: "n", options:, value: 2, id: "n_id", label: "Pick", input_data: { x: "y" }))

    expect(page).to have_css("input[type=hidden][name=n][value='2'][data-x=y]", visible: :all)
    expect(page).to have_css("button#n_id[aria-label=Pick] span", text: "Two")
    expect(page).to have_css("button[role=option][aria-selected=true]", text: "Two", visible: :all)
    expect(page).to have_no_css("input[type=text]", visible: :all)
  end

  it "falls back to the first option and omits the label when none matches", :aggregate_failures do
    render_inline(described_class.new(name: "n", options:, value: "zzz"))

    expect(page).to have_css("input[value='1']", visible: :all)
    expect(page).to have_no_css("button[aria-label]")
  end

  it "opens as a menu under the trigger by default and as a side panel when docked", :aggregate_failures do
    render_inline(described_class.new(name: "n", options:))
    expect(page).to have_css("[data-select-target=menu].left-0", visible: :all)
    expect(page).to have_css("[data-controller=select].relative", visible: :all)

    render_inline(described_class.new(name: "n", options:, dock: true))
    expect(page).to have_css("[data-select-target=menu].right-0.bottom-0", visible: :all)
    expect(page).to have_no_css("[data-controller=select].relative", visible: :all)
  end

  it "renders empty when there are no options", :aggregate_failures do
    render_inline(described_class.new(name: "n", options: []))

    expect(page).to have_css("input[type=hidden][value='']", visible: :all)
    expect(page).to have_css("[data-select-target=label]", text: "")
  end

  it "shows search past the threshold" do
    many = Array.new(described_class::SEARCH_THRESHOLD + 1) { |i| ["L#{i}", i] }
    render_inline(described_class.new(name: "n", options: many))

    expect(page).to have_css("input[data-select-target=search]", visible: :all)
  end

  it "honors an explicit searchable flag" do
    render_inline(described_class.new(name: "n", options:, searchable: true))

    expect(page).to have_css("input[data-select-target=search]", visible: :all)
  end

  it "splits sizing classes between wrapper and trigger", :aggregate_failures do
    render_inline(described_class.new(name: "n", options:, class: "w-28 font-mono"))

    expect(page).to have_css("div.relative.w-28[data-controller=select]:not(.w-full)")
    expect(page).to have_css("button.font-mono:not(.w-28)")
  end

  it "disables the trigger" do
    render_inline(described_class.new(name: "n", options:, disabled: true))

    expect(page).to have_css("button[data-select-target=trigger][disabled]")
  end

  it "is full width without sizing classes" do
    render_inline(described_class.new(name: "n", options:))

    expect(page).to have_css("div.relative.w-full[data-controller=select]")
  end
end
