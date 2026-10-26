class UserMenu::Component < ApplicationComponent
  def initialize(user:)
    @user = user
  end
end
