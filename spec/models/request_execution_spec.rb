require "rails_helper"

RSpec.describe RequestExecution do
  subject(:execution) { build(:request_execution) }

  describe "#error?" do
    it "reflects error_kind", :aggregate_failures do
      expect(execution).not_to be_error
      execution.error_kind = "timeout"
      expect(execution).to be_error
    end
  end

  describe "#status_class" do
    it "is error when failed" do
      execution.error_kind = "timeout"

      expect(execution.status_class).to eq(:error)
    end

    {
      200 => :success,
      302 => :success,
      404 => :client_error,
      500 => :server_error
    }.each do |status, expected|
      it "maps #{status} to #{expected}" do
        execution.status = status

        expect(execution.status_class).to eq(expected)
      end
    end
  end

  describe ".recent" do
    it "orders newest first" do
      old = create(:request_execution, created_at: 1.day.ago)
      recent = create(:request_execution, created_at: 1.minute.ago)

      expect(described_class.recent).to eq([recent, old])
    end
  end
end
