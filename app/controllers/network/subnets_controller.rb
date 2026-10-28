module Network
  class SubnetsController < BaseController
    def create
      attributes = params.expect(subnet: %i[network split contains])
      @result = Network::Subnets::Calculate.call(network: attributes[:network], split: attributes[:split], contains: attributes[:contains], environment: current_environment)
      render status: @result.success? ? :ok : :unprocessable_content
    end

    private

    def result_target
      "subnet_result"
    end
  end
end
