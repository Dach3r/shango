# Single dialog in the layout; the confirm-dialog controller routes every Turbo `data-turbo-confirm` through it.
class ConfirmDialog::Component < ApplicationComponent
  include ControlsHelper
end
