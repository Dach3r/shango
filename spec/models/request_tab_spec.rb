require "rails_helper"

RSpec.describe RequestTab do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:api_request) }

  it "enforces one tab per user and request at the database level" do
    tab = create(:request_tab)

    expect { described_class.new(user: tab.user, api_request: tab.api_request).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
