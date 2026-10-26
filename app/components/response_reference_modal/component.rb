class ResponseReferenceModal::Component < ApplicationComponent
  include ControlsHelper

  ATTRIBUTES = %w[body raw header url].freeze

  # Template the code editor and the plain-input autocomplete clone to edit a `{{response.…}}` reference; responses are the
  # same `{ id:, name:, method:, folder: }` hashes they receive.
  def initialize(responses:)
    @responses = responses
  end

  def render?
    @responses.any?
  end

  private

  def label(key)
    t("components.code_editor.#{key}")
  end

  def attribute_options
    ATTRIBUTES.map { |attribute| [label("response_#{attribute}"), attribute] }
  end

  def request_options
    @responses.map { |response| ["#{"[#{response[:folder]}] " if response[:folder]}#{response[:method]} #{response[:name]}", response[:id]] }
  end
end
