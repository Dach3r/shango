require "rails_helper"

# Sizes follow the zoom setting (root font size), so UI sizes must be rem; hairlines, oversized fills and positioning math stay px.
RSpec.describe "UI sizing" do
  let(:px) { /(?<![\d.])\d+(?:\.\d+)?px/ }
  let(:allowed) { /\A(?:[12]|1\.5|1000|9999)px\z/ }
  let(:files) { %w[app/components app/views app/javascript app/assets/tailwind].flat_map { |root| Rails.root.glob("#{root}/**/*.{erb,rb,js,css}") } }

  it "uses rem instead of px for sizes", :aggregate_failures do
    files.each do |file|
      file.each_line.with_index(1) do |line, number|
        offenders = line.scan(px).grep_v(allowed)
        next if offenders.empty? || line.include?("}px")

        expect(offenders).to be_empty, "#{file.relative_path_from(Rails.root)}:#{number} uses #{offenders.join(", ")}; use rem"
      end
    end
  end
end
