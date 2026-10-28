require "rails_helper"

RSpec.describe RequestTab do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:api_request).optional }
  it { is_expected.to belong_to(:request_draft).optional }

  it "enforces one tab per user and request at the database level" do
    tab = create(:request_tab)

    expect { described_class.new(user: tab.user, api_request: tab.api_request).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "enforces one tab per user and draft at the database level" do
    draft = create(:request_draft)
    described_class.create!(user: draft.user, request_draft: draft)

    expect { described_class.new(user: draft.user, request_draft: draft).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "points at exactly one of a request or a draft", :aggregate_failures do
    draft = create(:request_draft)

    expect { described_class.new(user: draft.user).save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    expect { described_class.new(user: draft.user, api_request: create(:api_request), request_draft: draft).save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
