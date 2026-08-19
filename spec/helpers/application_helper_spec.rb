require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#number_with_sign" do
    it "prefixes positive numbers with a plus" do
      expect(helper.number_with_sign(78)).to eq("+78")
    end

    it "prefixes negative numbers with a true minus sign" do
      expect(helper.number_with_sign(-102)).to eq("−102")
    end

    it "treats zero as positive" do
      expect(helper.number_with_sign(0)).to eq("+0")
    end

    it "delimits thousands" do
      expect(helper.number_with_sign(12_480)).to eq("+12,480")
    end

    it "rounds fractional values" do
      expect(helper.number_with_sign(45.4)).to eq("+45")
    end
  end

  describe "#structure_glyph_tone" do
    it "tints by the resource a structure concerns, extractor or not" do
      expect(helper.structure_glyph_tone(Structure.find("metal_extractor"))).to eq("text-metal")
      expect(helper.structure_glyph_tone(Structure.find("crystal_silo"))).to eq("text-crystal")
    end

    it "tints energy structures amber" do
      expect(helper.structure_glyph_tone(Structure.find("solar_array"))).to eq("text-amber")
    end

    it "leaves resource-agnostic facilities neutral" do
      expect(helper.structure_glyph_tone(Structure.find("shipyard"))).to eq("text-ink-2")
    end
  end

  describe "#structure_effect_summary" do
    let(:galaxy) { create(:galaxy) }
    let(:empire) { create(:empire, galaxy: galaxy, role: "foundry") }
    let(:system) { create(:system, galaxy: galaxy, metal_rate: 30, crystal_rate: 20) }
    let(:planet) { Planet.create!(empire: empire, system: system, name: "World") }
    let(:economy) { PlanetEconomy.new(planet) }

    def summary(key, level)
      helper.structure_effect_summary(Structure.find(key), level, economy)
    end

    it "describes extraction as output per tick" do
      expect(summary("metal_extractor", 1)).to match(%r{metal / tick})
    end

    it "describes energy structures as production" do
      expect(summary("solar_array", 2)).to match(/energy/)
    end

    it "describes refineries as a yield percentage" do
      expect(summary("refinery", 3)).to eq("+30% metal yield")
    end

    it "describes silos as capacity" do
      expect(summary("crystal_silo", 0)).to eq("10,000 crystal capacity")
    end

    it "describes the robotics bay as a build time reduction" do
      expect(summary("robotics_bay", 4)).to eq("−20% build time")
    end

    it "caps the robotics reduction at the build speed floor" do
      expect(summary("robotics_bay", 100)).to eq("−75% build time")
    end

    it "describes the research center by whether it is built" do
      expect(summary("research_center", 0)).to eq("Research locked")
      expect(summary("research_center", 1)).to eq("Research available")
    end

    it "describes the shipyard by whether it is built" do
      expect(summary("shipyard", 0)).to eq("No ships buildable here")
      expect(summary("shipyard", 2)).to eq("Ships buildable here")
    end
  end
end
