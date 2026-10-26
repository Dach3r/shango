require "rails_helper"

RSpec.describe Serviceable do
  let(:working_service) do
    Class.new do
      include Serviceable

      def initialize(value:)
        @value = value
      end

      private

      def perform
        @value * 2
      end
    end
  end

  let(:abstract_service) { Class.new { include Serviceable } }

  it "runs perform through .call" do
    expect(working_service.call(value: 2)).to eq(4)
  end

  it "raises when perform is not implemented" do
    stub_const("AbstractService", abstract_service)

    expect { AbstractService.call }.to raise_error(NotImplementedError, /AbstractService must implement/)
  end
end
