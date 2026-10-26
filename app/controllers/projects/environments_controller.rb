module Projects
  class EnvironmentsController < AuthenticatedController
    before_action :set_environment, only: %i[edit update destroy]

    def index
      @environments = current_project.environments.ordered.includes(:variables)
    end

    def new
      @environment = current_project.environments.new
    end

    def create
      result = Environments::Create.call(project: current_project, attributes: environment_attributes)
      return redirect_to(environments_path, notice: t(".created"), status: :see_other) if result.success?

      @environment = result.record
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      result = Environments::Update.call(environment: @environment, attributes: environment_attributes)
      return redirect_to(environments_path, notice: t(".updated"), status: :see_other) if result.success?

      render :edit, status: :unprocessable_entity
    end

    def destroy
      Environments::Destroy.call(environment: @environment)
      redirect_to environments_path, notice: t(".destroyed"), status: :see_other
    end

    private

    def set_environment
      @environment = current_project.environments.find(params[:id])
    end

    def environment_attributes
      params.expect(environment: [:name, { variables_attributes: [%i[id key value secret enabled _destroy]] }])
    end
  end
end
