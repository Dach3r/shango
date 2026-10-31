require "rails_helper"

RSpec.describe "Workbench runs" do
  include_context "with workbench project"

  before do
    ActiveJob::Base.queue_adapter = :test
    api_request
  end

  describe "GET /workbench/collections/:collection_id/runs/new" do
    it "asks for the options of a run of the collection", :aggregate_failures do
      get new_workbench_collection_run_path(collection), headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("workbench.runs.form.title"), "stop_on_failure", "persist_variables", "delay_ms")
    end

    it "names the folder when it is for one", :aggregate_failures do
      create(:api_request, collection:, folder:)

      get new_workbench_collection_run_path(collection, folder_id: folder.id), headers: turbo_headers

      expect(response.body).to include(folder.name, %(name="folder_id"))
    end

    it "preselects the member's environment" do
      environment = create(:environment, project:)
      membership.update!(current_environment: environment)

      get new_workbench_collection_run_path(collection), headers: turbo_headers

      expect(response.body).to match(/<option selected="selected" value="#{environment.id}"/)
    end

    it "does not reach a collection of another project" do
      get new_workbench_collection_run_path(foreign_collection)

      expect(response).to have_http_status(:not_found)
    end

    it "does not reach a folder of another project" do
      get new_workbench_collection_run_path(collection, folder_id: foreign_folder.id)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /workbench/collections/:collection_id/runs" do
    it "plans the run, queues it and goes to its page", :aggregate_failures do
      environment = create(:environment, project:)

      expect do
        post workbench_collection_runs_path(collection), params: { environment_id: environment.id, stop_on_failure: "1", delay_ms: "250", persist_variables: "0" }
      end.to have_enqueued_job(RunCollectionJob)

      run = CollectionRun.sole
      expect(response).to redirect_to(workbench_run_path(run))
      expect(run).to have_attributes(project:, collection:, user:, environment:, total_count: 1, options: { "stop_on_failure" => true, "persist_variables" => false, "delay_ms" => 250 })
    end

    it "runs a folder only" do
      create(:api_request, collection:, folder:)

      post workbench_collection_runs_path(collection), params: { folder_id: folder.id }

      expect(CollectionRun.sole).to have_attributes(folder:, total_count: 1)
    end

    it "ignores an environment of another project" do
      post workbench_collection_runs_path(collection), params: { environment_id: create(:environment).id }

      expect(CollectionRun.sole.environment).to be_nil
    end

    it "explains why it cannot start", :aggregate_failures do
      post workbench_collection_runs_path(create(:collection, project:)), headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("workbench.runs.form.errors.empty"))
      expect(CollectionRun.count).to eq(0)
    end

    it "explains the limit of requests", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_RUN_MAX_REQUESTS" => "1"))
      create(:api_request, collection:)

      post workbench_collection_runs_path(collection), headers: turbo_headers

      expect(response.body).to include(I18n.t("workbench.runs.form.errors.too_many", max: 1))
    end

    it "does not start a second run while one is going", :aggregate_failures do
      create(:collection_run, :running, project:, collection:, user:)

      post workbench_collection_runs_path(collection), headers: turbo_headers

      expect(response.body).to include(I18n.t("workbench.runs.form.errors.already_running"))
      expect(CollectionRun.count).to eq(1)
    end

    it "does not run a collection of another project" do
      post workbench_collection_runs_path(foreign_collection)

      expect(response).to have_http_status(:not_found)
    end

    it "is rate limited", :aggregate_failures do
      stub_const("ENV", ENV.to_h.merge("SHANGO_RATE_LIMIT_RUNS" => "1/60"))
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      post workbench_collection_runs_path(collection)
      CollectionRun.update_all(updated_at: 2.hours.ago) # rubocop:disable Rails/SkipsModelValidations
      post workbench_collection_runs_path(collection)

      expect(response).to redirect_to(workbench_root_path)
      expect(CollectionRun.count).to eq(1)
    end
  end

  describe "GET /workbench/collections/:collection_id/runs" do
    it "lists the runs of the collection, newest first", :aggregate_failures do
      other = create(:collection, project:)
      create(:collection_run, :completed, project:, collection:, user:)
      create(:collection_run, project:, collection: other, user:)

      get workbench_collection_runs_path(collection)

      expect(response).to have_http_status(:ok)
      expect(response.body.scan(%r{/workbench/runs/}).size).to eq(1)
      expect(response.body).to include(I18n.t("workbench.runs.index.new"))
    end

    it "says when there are none" do
      get workbench_collection_runs_path(collection)

      expect(response.body).to include(I18n.t("workbench.runs.index.empty"))
    end

    it "does not list the runs of another project" do
      get workbench_collection_runs_path(foreign_collection)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /workbench/runs/:id" do
    let(:run) { create(:collection_run, :completed, project:, collection:, user:, passed_count: 1, failed_count: 1, total_count: 3) }

    before do
      passed = create(:collection_run_item, collection_run: run, request_name: "Login", test_results: [{ "kind" => "assertion", "status" => "passed", "source" => "status", "operator" => "equals", "expected" => "200" }], http_status: 200, duration_ms: 12, url: "https://api.example.com/login")
      passed.update_columns(status: "passed")
      failed = create(:collection_run_item, collection_run: run, request_name: "Create", error_kind: "timeout", error_message: "Timed out")
      failed.update_columns(status: "failed")
      create(:collection_run_item, collection_run: run, request_name: "Plain").update_columns(status: "passed")
    end

    it "shows the summary and every request", :aggregate_failures do
      get workbench_run_path(run)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Login", "Create", "Timed out", "Status code equals 200", I18n.t("workbench.runs.statuses.completed_with_failures"), I18n.t("workbench.runs.show.no_tests"))
      expect(response.body).to include("turbo-cable-stream-source")
      expect(response.body).to include(workbench_run_path(run, format: :json), workbench_run_path(run, format: :xml))
    end

    it "offers to cancel an active run to who started it, and not afterwards", :aggregate_failures do
      active = create(:collection_run, :running, project:, collection:, user:)

      get workbench_run_path(active)
      expect(response.body).to include(workbench_run_cancellation_path(active))

      get workbench_run_path(run)
      expect(response.body).not_to include(workbench_run_cancellation_path(run))
    end

    it "shows why a run could not finish" do
      broken = create(:collection_run, :running, project:, collection:, user:)
      broken.update_columns(status: "failed", error: "access_revoked")

      get workbench_run_path(broken)

      expect(response.body).to include(I18n.t("workbench.runs.errors.access_revoked"))
    end

    it "downloads the report as JSON and JUnit", :aggregate_failures do
      get workbench_run_path(run, format: :json)
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Content-Disposition"]).to include("attachment", ".json")
      expect(JSON.parse(response.body)["items"].size).to eq(3)

      get workbench_run_path(run, format: :xml)
      expect(response.media_type).to eq("application/xml")
      expect(response.headers["Content-Disposition"]).to include("attachment", ".xml")
      expect(Nokogiri::XML(response.body).xpath("//testsuite").size).to eq(3)
    end

    it "does not show a run of another project" do
      get workbench_run_path(create(:collection_run))

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /workbench/runs/:run_id/cancellation" do
    let(:run) { create(:collection_run, :running, project:, collection:, user:) }

    it "cancels the run", :aggregate_failures do
      create(:collection_run_item, collection_run: run)

      post workbench_run_cancellation_path(run)

      expect(response).to redirect_to(workbench_run_path(run))
      expect(run.reload).to be_cancelled
      expect(run.items.map(&:status)).to eq(["skipped"])
    end

    it "does not let another member cancel it", :aggregate_failures do
      other = create(:collection_run, :running, project:, collection:, user: create(:user))
      membership.update!(role: "member") if membership.owner? && project.memberships.owner.count > 1

      post workbench_run_cancellation_path(other)

      expect(run).to be_running
    end

    it "does not reach a run of another project" do
      post workbench_run_cancellation_path(create(:collection_run, :running))

      expect(response).to have_http_status(:not_found)
    end
  end
end
