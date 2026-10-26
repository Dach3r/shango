class ApplicationComponent < ViewComponent::Base
  include LucideRails::RailsHelper

  # Shared by Input and Button so every form control renders at the same height.
  CONTROL_SIZE = "box-border h-14 min-h-14 max-h-14"
end
