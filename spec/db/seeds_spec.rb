require "rails_helper"

RSpec.describe "db/seeds" do
  let(:seeds_file) { Rails.root.join("db/seeds.rb") }
  let(:account_file) { Rails.root.join("db/seeds/development/performance_account.seeds.rb") }

  describe "loading" do
    let(:root) { Pathname(Dir.mktmpdir) }

    before do
      seeds_file
      %w[base development test staging].each { |scope| root.join("db/seeds/#{scope}").mkpath }
      %w[base/b_second base/a_first development/only_dev test/only_test staging/only_staging].each do |name|
        root.join("db/seeds/#{name}.seeds.rb").write("($seeded ||= []) << \"#{name}\"")
      end
      root.join("db/seeds/base/ignored.rb").write("($seeded ||= []) << \"ignored\"")
      allow(Rails).to receive(:root).and_return(root)
      allow($stdout).to receive(:puts)
      $seeded = []
    end

    after do
      FileUtils.remove_entry(root)
      $seeded = nil
    end

    it "loads the base files and then the ones of the current environment", :aggregate_failures do
      load seeds_file

      expect($seeded).to eq(%w[base/a_first base/b_second test/only_test])
    end

    it "loads the development files only in development", :aggregate_failures do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      load seeds_file

      expect($seeded).to eq(%w[base/a_first base/b_second development/only_dev])
    end
  end

  describe "development/performance_account" do
    let(:user) { User.find_by!(email: "dev@shango.test") }

    def seed(**extra)
      Object.send(:remove_const, :Seeds) if defined?(Seeds)
      stub_const("ENV", ENV.to_h.merge(extra.transform_keys(&:to_s)))
      allow($stdout).to receive(:puts)
      load account_file
    end

    after { Object.send(:remove_const, :Seeds) if defined?(Seeds) }

    it "builds a confirmed account with the Restful-Booker project imported", :aggregate_failures do
      seed
      project = user.current_membership.project

      expect(user).to be_confirmed
      expect(user.valid_password?("password")).to be(true)
      expect(project.name).to eq("Restful Booker")
      expect(user.available_memberships.count).to eq(1)
      expect(project.collections.pluck(:name)).to eq(["restful-booker API"])
      expect(project.api_requests.where.not(collection_id: nil)).to be_any
      expect(project.environments.flat_map { |environment| environment.variables.map(&:key) }).to include("baseUrl")
      expect(user.current_membership.current_environment).to eq(project.environments.first)
    end

    it "keeps an existing account untouched", :aggregate_failures do
      seed
      expect { seed }.not_to(change { [User.count, Project.count, ApiRequest.count] })
    end

    it "rebuilds the account when asked to", :aggregate_failures do
      seed
      old_ids = Project.ids
      seed(SEED_RESET: "1")

      expect(User.count).to eq(1)
      expect(Project.count).to eq(1)
      expect(Project.ids & old_ids).to be_empty
    end

    it "fails loudly when an import fails" do
      allow(ApiClient::Imports::Import).to receive(:call).and_return(Result.failure(error: "boom"))

      expect { seed }.to raise_error("boom")
    end
  end
end
