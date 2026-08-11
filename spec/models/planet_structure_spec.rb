require 'rails_helper'

RSpec.describe PlanetStructure, type: :model do
  let(:galaxy) { create(:galaxy) }
  let(:planet) do
    Planet.create!(
      empire: create(:empire, galaxy: galaxy),
      sector: create(:sector, galaxy: galaxy),
      name: "World"
    )
  end

  describe "validations" do
    it "accepts a known structure kind" do
      expect(planet.structures.new(kind: "solar_array", level: 1)).to be_valid
    end

    it "rejects an unknown structure kind" do
      expect(planet.structures.new(kind: "orbital_casino", level: 1)).not_to be_valid
    end

    it "rejects a negative level" do
      expect(planet.structures.new(kind: "solar_array", level: -1)).not_to be_valid
    end

    it "allows a structure only once per planet" do
      planet.structures.create!(kind: "solar_array", level: 1)

      expect(planet.structures.new(kind: "solar_array", level: 2)).not_to be_valid
    end
  end

  describe "delegation and derived values" do
    let(:structure) { planet.structures.create!(kind: "metal_extractor", level: 3) }

    it "delegates presentation to the catalogue definition" do
      expect(structure.name).to eq("Metal Extractor")
      expect(structure.category).to eq("extraction")
      expect(structure.summary).to be_present
    end

    it "derives energy draw and cost from the level" do
      expect(structure.energy_draw).to eq(34 * 3)
      expect(structure.energy_output).to eq(0)
      expect(structure.upgrade_cost).to eq(Structure.find("metal_extractor").upgrade_cost(3))
    end

    it "knows whether it has been built" do
      expect(structure).to be_built
      expect(planet.structures.create!(kind: "refinery", level: 0)).not_to be_built
    end
  end

  describe ".built" do
    it "returns only structures above level zero" do
      planet.structures.create!(kind: "solar_array", level: 2)
      planet.structures.create!(kind: "refinery", level: 0)

      expect(planet.structures.built.map(&:kind)).to eq([ "solar_array" ])
    end
  end
end
