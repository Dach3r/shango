module ApiClient
  # Stores variables that a run produced (extractors, scripts) in the environment, when the user may edit it. A variable that
  # exists keeps its secret flag (and is switched on, since the run needs it); a new one is secret only if `secrets` says so.
  # Result#record is how many variables were written; a failure carries `error` (:no_environment, :not_permitted).
  class VariableWriteback
    include Serviceable

    def initialize(environment:, user:, values:, secrets: [])
      @environment = environment
      @user = user
      @values = values
      @secrets = secrets
    end

    private

    def perform
      return Result.failure(error: :no_environment) unless @environment
      return Result.failure(error: :not_permitted) unless permitted?
      return Result.success(0) if @values.empty?

      @environment.transaction { @values.each { |key, value| write(key, value) } }
      @environment.variables.reset
      Result.success(@values.size)
    end

    def permitted?
      membership = Membership.active.find_by(project_id: @environment.project_id, user_id: @user&.id)
      membership.present? && EnvironmentPolicy.new(membership, @environment).update?
    end

    def write(key, value)
      variable = @environment.variables.find_or_initialize_by(key:)
      variable.secret = @secrets.include?(key) if variable.new_record?
      variable.assign_attributes(value:, enabled: true)
      variable.save!
    end
  end
end
