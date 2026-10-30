require "rails_helper"

RSpec.describe ApplicationCable::Connection do
  let(:user) { create(:user) }

  it "connects a signed-in user" do
    connect "/cable", env: { "warden" => instance_double(Warden::Proxy, user: user) }

    expect(connection.current_user).to eq(user)
  end

  it "rejects a visitor" do
    expect { connect "/cable", env: { "warden" => instance_double(Warden::Proxy, user: nil) } }.to have_rejected_connection
  end
end
