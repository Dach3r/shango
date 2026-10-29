require "rails_helper"

RSpec.describe Monitoring::Guard do
  it "tells cloud metadata addresses apart", :aggregate_failures do
    expect(described_class.metadata?("169.254.169.254")).to be(true)
    expect(described_class.metadata?("fd00:ec2::254")).to be(true)
    expect(described_class.metadata?("::ffff:169.254.169.254")).to be(true)
    expect(described_class.metadata?("203.0.113.9")).to be(false)
    expect(described_class.metadata?("2001:db8::1")).to be(false)
    expect(described_class.metadata?("not an address")).to be(false)
  end
end
