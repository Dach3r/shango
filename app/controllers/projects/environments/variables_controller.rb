module Projects
  module Environments
    # Inline create and edit of one variable's value from the editors' hover card.
    class VariablesController < AuthenticatedController
      def create
        environment = current_project.environments.find(params[:environment_id])
        attributes = params.expect(variable: %i[key value])
        result = CreateVariable.call(environment:, key: attributes[:key], value: attributes[:value])
        return head(:unprocessable_entity) unless result.success?

        variable = result.record
        render json: { name: variable.key, set: variable.value.present?, value: variable.masked_value, secret: variable.secret, url: environment_variable_path(environment, variable) }, status: :created
      end

      def update
        variable = current_project.environments.find(params[:environment_id]).variables.find(params[:id])
        result = UpdateVariable.call(variable:, value: params.expect(variable: [:value])[:value])
        return head(:unprocessable_entity) unless result.success?

        render json: { set: variable.value.present?, value: variable.masked_value }
      end
    end
  end
end
