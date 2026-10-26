class AuthenticatedController < ApplicationController
  include ProjectContext

  layout -> { turbo_frame_request? ? "turbo_rails/frame" : "app" }

  before_action :authenticate_user!
  before_action :require_project
end
