require "rails_helper"

RSpec.describe NotificationChannel do
  let(:project) { create(:project) }

  it "encrypts the target and the signing secret", :aggregate_failures do
    channel = create(:notification_channel, project:)
    raw = described_class.connection.select_one("SELECT target, signing_secret FROM notification_channels WHERE id = #{described_class.connection.quote(channel.id)}")

    expect(raw["target"]).not_to include("hooks.example.com")
    expect(raw["signing_secret"]).not_to include(channel.signing_secret)
    expect(channel.signing_secret).to start_with("whsec_")
  end

  it "gives only webhooks a signing secret" do
    expect(create(:notification_channel, :email, project:).signing_secret).to be_nil
  end

  it "cleans up and validates email addresses", :aggregate_failures do
    channel = build(:notification_channel, :email, project:, target: " a@example.com,\nb@example.com; a@example.com ")

    expect(channel).to be_valid
    expect(channel.target).to eq("a@example.com, b@example.com")
    expect(channel.addresses).to eq(%w[a@example.com b@example.com])
    expect(channel.masked_target).to eq("a@example.com, b@example.com")
    expect(build(:notification_channel, :email, target: "a@example.com, nope")).to have_error(:target, :invalid_address)
    expect(build(:notification_channel, :email, target: " ")).to have_error(:target, :blank)
    expect(build(:notification_channel, :email, target: (1..11).map { |n| "u#{n}@example.com" }.join(","))).to have_error(:target, :too_many_addresses)
  end

  it "validates webhook URLs", :aggregate_failures do
    expect(build(:notification_channel, target: "")).to have_error(:target, :blank)
    expect(build(:notification_channel, target: "https://example.com/#{"a" * 2048}")).to have_error(:target, :too_long)
    expect(build(:notification_channel, target: "ftp://example.com")).to have_error(:target, :invalid_url)
    expect(build(:notification_channel, target: "https://user:pass@example.com")).to have_error(:target, :invalid_url)
    expect(build(:notification_channel, target: "https://exa mple.com")).to have_error(:target, :invalid_url)
    expect(build(:notification_channel, target: "  https://example.com/hook  ").tap(&:valid?).target).to eq("https://example.com/hook")
  end

  it "masks a URL to its scheme, host and last characters" do
    expect(build(:notification_channel, target: "https://hooks.example.com/T000/B000/secretXYZ9").masked_target).to eq("https://hooks.example.com/…XYZ9")
  end

  it "checks the locale, the kind and the limit per project", :aggregate_failures do
    expect(build(:notification_channel, locale: "xx")).to have_error(:locale, :inclusion)
    expect(build(:notification_channel, kind: "pager")).to have_error(:kind, :inclusion)
    channel = create(:notification_channel, project:)
    channel.kind = "email"
    expect(channel).to have_error(:kind, :immutable)
    stub_const("NotificationChannel::PER_PROJECT", 1)
    expect(build(:notification_channel, project:)).to have_error(:base, :project_limit)
  end

  it "regenerates the signing secret" do
    channel = create(:notification_channel, project:)

    expect { channel.regenerate_signing_secret }.to(change(channel, :signing_secret))
  end

  it "has no URI for an unparsable target or an email channel, and no addresses for a URL", :aggregate_failures do
    expect(build(:notification_channel, target: "http://[bad").uri).to be_nil
    expect(build(:notification_channel, target: "http://[bad").masked_target).to eq(":///…[bad")
    expect(build(:notification_channel, :email).uri).to be_nil
    expect(build(:notification_channel).addresses).to eq([])
  end

  it "deletes its links and deliveries with it", :aggregate_failures do
    link = create(:monitor_channel, uptime_monitor: create(:uptime_monitor, project:), notification_channel: create(:notification_channel, project:))
    create(:notification_delivery, notification_channel: link.notification_channel)
    link.notification_channel.destroy!

    expect(MonitorChannel.count).to eq(0)
    expect(NotificationDelivery.count).to eq(0)
  end

  it "accepts only the incoming-webhook URLs of Slack and Discord", :aggregate_failures do
    expect(build(:notification_channel, :slack)).to be_valid
    expect(build(:notification_channel, :slack, target: "https://hooks.slack.com/triggers/T0/1/abc")).to be_valid
    expect(build(:notification_channel, :discord)).to be_valid
    expect(build(:notification_channel, :discord, target: "https://discordapp.com/api/webhooks/1/x")).to be_valid
    expect(build(:notification_channel, :discord, target: "https://DISCORD.com/api/webhooks/1/x")).to be_valid
    {
      slack: %w[http://hooks.slack.com/services/x https://hooks.slack.com:8443/services/x https://evil.example/services/x https://hooks.slack.com.evil.example/services/x
                https://hooks.slack.com/api/x],
      discord: %w[https://discord.com/webhooks/1/x https://discord.com:444/api/webhooks/1/x https://cdn.discord.com/api/webhooks/1/x http://discord.com/api/webhooks/1/x]
    }.each do |kind, targets|
      targets.each { |target| expect(build(:notification_channel, kind, target:)).to have_error(:target, :"invalid_#{kind}_url"), target }
    end
    expect(build(:notification_channel, :slack, target: "https://user@hooks.slack.com/services/x")).to have_error(:target, :invalid_url)
  end
end
