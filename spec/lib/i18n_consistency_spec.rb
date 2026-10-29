require "rails_helper"

RSpec.describe "Locale files" do
  PLURALS = %w[zero one two few many other].freeze

  def flatten(hash, prefix = nil)
    hash.flat_map do |key, value|
      path = [prefix, key].compact.join(".")
      value.is_a?(Hash) ? flatten(value, path) : [[path, value]]
    end
  end

  def load_locale(name, locale)
    flatten(YAML.load_file(Rails.root.join("config/locales/#{locale}/#{name}.#{locale}.yml")).fetch(locale.to_s)).to_h
  end

  def placeholders(value)
    Array(value).join(" ").scan(/%\{(\w+)\}/).flatten.sort
  end

  def base_key(key)
    parts = key.split(".")
    PLURALS.include?(parts.last) ? parts[0..-2].join(".") : key
  end

  def base_keys(translations)
    translations.keys.map { |key| base_key(key) }.uniq
  end

  it "supports every available locale" do
    expect(I18n.available_locales).to eq(%i[en es zh-CN hi pt-BR ru ja de fr])
  end

  %w[views workbench network team monitoring].each do |name|
    (I18n.available_locales - [:en]).each do |locale|
      context "with #{name} in #{locale}" do
        let(:en) { load_locale(name, :en) }
        let(:other) { load_locale(name, locale) }

        it "has the same keys as en", :aggregate_failures do
          expect(base_keys(en) - base_keys(other)).to be_empty
          expect(base_keys(other) - base_keys(en)).to be_empty
        end

        it "uses the same interpolation variables as en", :aggregate_failures do
          en.each do |key, value|
            next unless other.key?(key)
            next if PLURALS.include?(key.split(".").last) && !key.end_with?(".other")

            expect(placeholders(other[key])).to eq(placeholders(value)), "#{name}.#{key} interpolations differ"
          end
        end

        it "has no blank translations" do
          blank = other.select { |_, value| value.nil? || value.to_s.strip.empty? }.keys
          expect(blank).to be_empty
        end
      end
    end
  end
end

RSpec.describe "Stimulus wiring" do
  let(:registered) do
    Rails.root.glob("app/javascript/controllers/*_controller.js").map { |f| f.basename(".js").to_s.delete_suffix("_controller").tr("_", "-") }
  end
  let(:sources) { Rails.root.glob("app/{views,components,helpers}/**/*.{erb,rb}") }

  it "only references controllers that exist", :aggregate_failures do
    sources.each do |file|
      content = file.read
      names = content.scan(/data-controller="([^"]+)"/).flatten + content.scan(/controller: \(?"([^"]+)"/).flatten
      names.flat_map(&:split).each do |name|
        expect(registered).to include(name), "#{file.relative_path_from(Rails.root)} references missing controller #{name}"
      end
    end
  end

  it "only dispatches actions to controllers that exist", :aggregate_failures do
    sources.each do |file|
      file.read.scan(/(?:->|"|\s)(?:[a-z]+(?:\.[a-z]+)?@(?:window|document)->)?([a-z][a-z-]+)#[a-zA-Z]+/).flatten.each do |name|
        expect(registered).to include(name), "#{file.relative_path_from(Rails.root)} dispatches to missing controller #{name}"
      end
    end
  end
  describe "targets and actions" do
    let(:controllers) do
      Rails.root.glob("app/javascript/controllers/*_controller.js").to_h do |file|
        source = file.read
        [file.basename(".js").to_s.delete_suffix("_controller").tr("_", "-"),
         { targets: source[/static targets = \[([^\]]*)\]/, 1].to_s.scan(/"(\w+)"/).flatten,
           methods: source.scan(/^\s+(?:async\s+|get\s+)?(\w+)\(/).flatten }]
      end
    end

    it "only uses targets declared by the controller", :aggregate_failures do
      sources.each do |file|
        content = file.read
        pairs = content.scan(/data-([a-z-]+)-target="([^"]+)"/) + content.scan(/([a-z_]+)_target: ?"([^"]+)"/).map { |c, t| [c.tr("_", "-"), t] }
        pairs.each do |name, target|
          expect(controllers.dig(name, :targets)).to include(target), "#{file.relative_path_from(Rails.root)}: #{name} has no target #{target}"
        end
      end
    end

    it "only calls actions defined by the controller", :aggregate_failures do
      sources.each do |file|
        file.read.scan(/([a-z][a-z-]+)#(\w+)/).each do |name, method|
          next unless controllers.key?(name)

          expect(controllers.dig(name, :methods)).to include(method), "#{file.relative_path_from(Rails.root)}: #{name}##{method} is not defined"
        end
      end
    end
  end
end
