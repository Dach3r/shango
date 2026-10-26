require "rails_helper"

RSpec.describe RequestTab do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:api_request) }
end
