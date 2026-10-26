require "simplecov"

SimpleCov.start "rails" do
  enable_coverage :branch
  coverage_dir ENV.fetch("COVERAGE_DIR", "coverage")
  minimum_coverage line: 100, branch: 100 unless ENV["PARTIAL_RUN"]
  track_files "app/**/*.rb"
  skip %r{\A/(spec|config|db|bin|vendor)/}
  group "Components", "app/components"
  group "Services", "app/services"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
