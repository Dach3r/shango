class Topbar::Component < ApplicationComponent
  def initialize(user:, title: nil)
    @user = user
    @title = title
  end
end
