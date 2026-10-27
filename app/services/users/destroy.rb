module Users
  # Cancels an account after checking the password. Projects only the user belongs to go away with them; a project that
  # still has other members cannot be left without an owner, so the user must hand it over first.
  class Destroy
    include Serviceable

    def initialize(user:, password:)
      @user = user
      @password = password
    end

    private

    def perform
      return Result.failure(@user, error: :wrong_password) unless @user.valid_password?(@password.to_s)
      return Result.failure(@user, error: :sole_owner, projects: impact.blocked.map(&:name)) if impact.blocked?

      User.transaction do
        impact.doomed.each(&:destroy!)
        @user.destroy!
      end
      Result.success(@user)
    end

    def impact
      @impact ||= AccountImpact.new(@user)
    end
  end
end
