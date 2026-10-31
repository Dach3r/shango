require "rails_helper"

RSpec.describe CollectionRunItem do
  let(:item) { create(:collection_run_item) }

  it "runs and then passes, fails or is skipped", :aggregate_failures do
    expect(item).to be_pending
    item.start!
    item.mark_passed!
    expect(item).to be_passed

    failing = create(:collection_run_item)
    failing.start!
    failing.mark_failed!
    expect(failing).to be_failed

    skipped = create(:collection_run_item)
    skipped.mark_skipped!
    expect(skipped).to be_skipped
    expect(create(:collection_run_item).tap(&:start!).tap(&:mark_skipped!)).to be_skipped
  end

  it "only finishes what is running" do
    expect { item.mark_passed! }.to raise_error(AASM::InvalidTransition)
  end

  it "counts its tests and tells about errors", :aggregate_failures do
    item.test_results = [{ "status" => "passed" }, { "status" => "failed" }, { "status" => "failed" }, { "status" => "warning" }]

    expect(item).to have_attributes(passed_tests: 1, failed_tests: 2)
    expect(item).not_to be_error
    item.error_kind = "timeout"
    expect(item).to be_error
  end

  it "survives the deletion of its request, keeping the name", :aggregate_failures do
    name = item.request_name
    item.api_request.destroy!

    expect(item.reload.api_request).to be_nil
    expect(item.request_name).to eq(name)
  end
end
