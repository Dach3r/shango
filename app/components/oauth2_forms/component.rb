class Oauth2Forms::Component < ApplicationComponent
  # The hidden forms behind the OAuth buttons of AuthFields. They live outside the editor form
  # (forms cannot nest) and are targeted through the buttons' `form` attribute.
  def initialize(owner:)
    @owner = owner
  end

  def render?
    @owner.persisted? && @owner.auth_type == "oauth2"
  end

  private

  def owner_params
    { owner_type: @owner.class.name, owner_id: @owner.id }
  end

  def dom_id_for(kind)
    "oauth2-#{kind}-#{@owner.id}"
  end
end
