class EmptyState::Component < ApplicationComponent
  # icon/title/description fill the block; the content (optional) holds the actions, e.g. buttons.
  def initialize(icon:, title:, description: nil, **options)
    @icon = icon
    @title = title
    @description = description
    @options = options
  end

  private

  def classes
    class_names("flex min-h-full flex-1 items-center justify-center p-8", @options[:class])
  end
end
