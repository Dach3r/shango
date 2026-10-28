require "rails_helper"

RSpec.describe Network::Tools do
  it "lists the tools in rail order" do
    expect(described_class.names).to eq(%w[dns reverse_dns ports ping])
  end

  it "finds a tool by name", :aggregate_failures do
    expect(described_class.find(:ports)).to have_attributes(icon: "radar", group: "connectivity")
    expect { described_class.find("nmap") }.to raise_error(KeyError, /nmap/)
  end

  it "keeps a preset on the page, kind and history of the tool it presets", :aggregate_failures do
    expect(described_class.find("reverse_dns")).to have_attributes(kind: "dns", defaults: { "type" => "PTR" })
    expect(described_class.find("ping")).to have_attributes(kind: "ping", defaults: {})
  end

  it "finds the tool of a saved run from what was typed", :aggregate_failures do
    expect(described_class.for_run("dns", { "domain" => "8.8.8.8", "type" => "PTR" }).name).to eq("reverse_dns")
    expect(described_class.for_run(:dns, { "domain" => "example.com", "type" => "A" }).name).to eq("dns")
    expect(described_class.for_run("ports", nil).name).to eq("ports")
  end

  it "has a page for every kind of saved run" do
    expect(described_class.names).to include(*NetworkCheck.kinds.keys)
  end

  it "labels every tool and group in each locale", :aggregate_failures do
    I18n.available_locales.each do |locale|
      described_class::ALL.each do |tool|
        expect(I18n.exists?("network.tabs.#{tool.name}", locale)).to be(true)
        expect(I18n.exists?("network.groups.#{tool.group}", locale)).to be(true)
      end
    end
  end
end
