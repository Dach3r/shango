class UserMenu::Component < ApplicationComponent
  def initialize(user:, compact: false)
    @user = user
    @compact = compact
  end
end
