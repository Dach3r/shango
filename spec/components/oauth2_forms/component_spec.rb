require "rails_helper"

RSpec.describe Oauth2Forms::Component, type: :component do
  it "renders the three hidden forms for a persisted oauth2 owner", :aggregate_failures do
    collection = create(:collection, auth_type: "oauth2")
    render_inline(described_class.new(owner: collection))

    expect(page).to have_css("form#oauth2-token-#{collection.id}", visible: :all)
    expect(page).to have_css("form#oauth2-authorization-#{collection.id}", visible: :all)
    expect(page).to have_css("form#oauth2-clear-#{collection.id} input[name=owner_type][value=Collection]", visible: :all)
  end

  it "renders nothing for a new owner" do
    render_inline(described_class.new(owner: build(:collection, auth_type: "oauth2")))

    expect(page).to have_no_css("form", visible: :all)
  end

  it "renders nothing for other auth types" do
    render_inline(described_class.new(owner: create(:collection)))

    expect(page).to have_no_css("form", visible: :all)
  end
end
