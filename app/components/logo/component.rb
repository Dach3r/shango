class Logo::Component < ApplicationComponent
  CLASSES = "inline-flex items-center gap-2.5"

  def initialize(href:, **options)
    @href = href
    @options = options
  end

  def call
    link_to @href, **@options, class: class_names(CLASSES, @options[:class]) do
      safe_join([
        render(Bolt::Component.new(class: "h-7 w-auto fill-accent")),
        tag.span(ApplicationHelper::CONFIG[:name], class: "text-2xl font-semibold tracking-tight text-ink")
      ])
    end
  end
end
