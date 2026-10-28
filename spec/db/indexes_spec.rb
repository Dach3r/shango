require "rails_helper"

RSpec.describe "Database indexes" do
  let(:connection) { ActiveRecord::Base.connection }

  it "indexes the saved-response history lookup" do
    expect(connection.index_exists?(:request_executions, %i[project_id user_id created_at])).to be(true)
  end

  it "indexes the sidebar tree order" do
    expect(connection.index_exists?(:api_requests, %i[project_id collection_id folder_id position])).to be(true)
  end

  it "keeps one draft of pending edits per user and request", :aggregate_failures do
    index = connection.indexes(:request_drafts).find { |candidate| candidate.name == "index_request_drafts_on_user_and_api_request" }

    expect(index).to have_attributes(columns: %w[user_id api_request_id], unique: true, where: "(api_request_id IS NOT NULL)")
  end

  it "indexes drafts by last update for the purge" do
    expect(connection.index_exists?(:request_drafts, :updated_at)).to be(true)
  end
end
