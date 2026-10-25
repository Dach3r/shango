class Link::Component < ApplicationComponent
  CLASSES = "font-semibold text-brand-500 hover:text-brand-700"

  def initialize(label:, href:, **options)
    @label = label
    @href = href
    @options = options
  end

  def call
    link_to @label, @href, **@options, class: class_names(CLASSES, @options[:class])
  end
end
