class Link::Component < ApplicationComponent
  CLASSES = "font-medium text-accent hover:text-accent-hover"

  def initialize(label:, href:, **options)
    @label = label
    @href = href
    @options = options
  end

  def call
    link_to @label, @href, **@options, class: class_names(CLASSES, @options[:class])
  end
end
