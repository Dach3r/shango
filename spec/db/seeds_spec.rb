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
    let(:sizes) do
      { "SEED_PROJECTS" => "3", "SEED_COLLECTIONS" => "2", "SEED_FOLDERS" => "6", "SEED_REQUESTS" => "8", "SEED_ENVIRONMENTS" => "2", "SEED_VARIABLES" => "4",
        "SEED_EXECUTIONS" => "5", "SEED_COOKIES" => "4", "SEED_DRAFTS" => "3", "SEED_TABS" => "4", "SEED_TEAMMATES" => "1" }
    end
    let(:user) { User.find_by!(email: "perf@shango.test") }

    def seed(**extra)
      Object.send(:remove_const, :Seeds) if defined?(Seeds)
      stub_const("ENV", ENV.to_h.merge(sizes, extra.transform_keys(&:to_s)))
      allow($stdout).to receive(:puts)
      load account_file
    end

    after { Object.send(:remove_const, :Seeds) if defined?(Seeds) }

    it "builds a confirmed account with data in every area", :aggregate_failures do
      seed

      expect(user).to be_confirmed
      expect(user.valid_password?("password123")).to be(true)
      expect(user.available_memberships.count).to eq(3)
      expect(user.current_membership.project).to be_present
      expect(Project.count).to eq(3)
      expect(Collection.count).to eq(6)
      expect(Folder.count).to eq(36)
      expect(ApiRequest.where.not(collection_id: nil).count).to eq(48)
      expect(ApiRequest.drafts.where(user:).count).to eq(9)
      expect(RequestExecution.count).to eq(240)
      expect(Environment.count).to eq(6)
      expect(Variable.count).to eq(24)
      expect(Cookie.count).to eq(12)
      expect(NetworkCheck.count).to eq(3 * 3 * NetworkCheck::KEEP_PER_KIND)
      expect(RequestTab.where(user:).count).to eq(6)
    end

    it "creates rows the app can read back", :aggregate_failures do
      seed
      project = user.current_membership.project

      expect(Variable.where.not(value: nil).all? { |variable| variable.value.present? }).to be(true)
      expect(Variable.where(secret: true)).to be_any
      expect(ApiRequest.where(auth_type: "bearer").first.auth_config).to include("token")
      expect(NetworkCheck.all.map { |check| check.digest.tone }).to all(be_in(%w[ok warn bad]))
      expect(NetworkCheck.all.map(&:outcome)).to eq(NetworkCheck.all.map { |check| check.digest.tone })
      expect(ApiClient::Tree::Load.call(project:).size).to eq(2)
      expect(ApiClient::Tabs::Load.call(project:, user:).size).to eq(6)
      expect(ApiClient::Executions::History.call(project:, user:)).to be_present
    end

    it "keeps an existing account untouched", :aggregate_failures do
      seed
      expect { seed }.not_to(change { [User.count, Project.count, ApiRequest.count] })
    end

    it "rebuilds the account when asked to", :aggregate_failures do
      seed
      old_ids = Project.ids
      seed(SEED_RESET: "1", SEED_PROJECTS: "2")

      expect(Project.count).to eq(2)
      expect(Project.ids & old_ids).to be_empty
      expect(User.where("email LIKE '%@shango.test'").count).to eq(2)
      expect(RequestExecution.count).to eq(160)
    end

    it "works without teammates" do
      seed(SEED_TEAMMATES: "0")

      expect(User.count).to eq(1)
    end
  end
end
