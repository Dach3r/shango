module Projects
  module Environments
    # Inline edit of one variable's value from the editors' hover card.
    class VariablesController < AuthenticatedController
      def update
        variable = current_project.environments.find(params[:environment_id]).variables.find(params[:id])
        result = UpdateVariable.call(variable:, value: params.expect(variable: [:value])[:value])
        return head(:unprocessable_entity) unless result.success?

        render json: { set: variable.value.present?, value: variable.masked_value }
      end
    end
  end
end
