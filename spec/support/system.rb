require "capybara/cuprite"

Capybara.default_max_wait_time = 10

RSpec.configure do |config|
  config.include Warden::Test::Helpers, type: :system
  config.before(:each, type: :system) do
    driven_by :cuprite, screen_size: [1400, 900], options: { headless: true, process_timeout: 30, timeout: 60, protocol_timeout: 90, browser_options: { "no-sandbox" => nil } }
  end
  config.after(:each, type: :system) { Warden.test_reset! }
end
