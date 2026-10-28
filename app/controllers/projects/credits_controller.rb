module Projects
  class CreditsController < AuthenticatedController
    skip_after_action :verify_authorized

    def index
      @omarchy_themes = Membership::OMARCHY_CREDITS
    end
  end
end
