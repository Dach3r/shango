require "rails_helper"

RSpec.describe ApplicationMailer do
  it "sets the default sender" do
    expect(described_class.default[:from].call).to eq("shango@localhost")
  end
end
