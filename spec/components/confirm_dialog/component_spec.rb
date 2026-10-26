require "rails_helper"

RSpec.describe ConfirmDialog::Component, type: :component do
  it "renders the dialog with its message slot and actions", :aggregate_failures do
    render_inline(described_class.new)

    expect(page).to have_css("dialog[data-controller=confirm-dialog]")
    expect(page).to have_css("[data-confirm-dialog-target=message]")
    expect(page).to have_button(I18n.t("components.confirm_dialog.cancel"))
    expect(page).to have_button(I18n.t("components.confirm_dialog.confirm"))
  end
end
