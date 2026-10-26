module ComponentHelpers
  def page
    Capybara::Node::Simple.new(rendered_content)
  end
end

RSpec.configure { |config| config.include ComponentHelpers, type: :component }
