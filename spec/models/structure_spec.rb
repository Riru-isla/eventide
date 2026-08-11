require 'ostruct'
require 'rails_helper'

RSpec.describe Structure, type: :model do
  describe ".find" do
    it "looks a structure up by key" do
      expect(described_class.find("solar_array").name).to eq("Solar Array")
    end

    it "returns nil for an unknown key" do
      expect(described_class.find("orbital_casino")).to be_nil
    end

    it "raises for an unknown key when using find!" do
      expect { described_class.find!("orbital_casino") }.to raise_error(KeyError)
    end
  end

  describe ".in_category" do
    it "returns only structures in that category" do
      keys = described_class.in_category("extraction").map(&:key)

      expect(keys).to contain_exactly("metal_extractor", "crystal_extractor")
    end
  end

  describe "energy" do
    it "scales draw with level" do
      expect(described_class.find("metal_extractor").energy_draw(12)).to eq(34 * 12)
    end

    it "scales output with level" do
      expect(described_class.find("solar_array").energy_output(9)).to eq(900)
    end

    it "draws nothing at level zero" do
      expect(described_class.find("metal_extractor").energy_draw(0)).to eq(0)
    end
  end

  describe "#upgrade_cost" do
    it "charges the base cost for the first level" do
      cost = described_class.find("metal_extractor").upgrade_cost(0)

      expect(cost).to eq(metal: 60, crystal: 15)
    end

    it "grows with each level" do
      structure = described_class.find("metal_extractor")

      expect(structure.upgrade_cost(3)[:metal]).to be > structure.upgrade_cost(2)[:metal]
    end
  end

  describe "categories" do
    it "classifies extraction and energy structures" do
      expect(described_class.find("metal_extractor")).to be_extraction
      expect(described_class.find("metal_extractor")).not_to be_energy
      expect(described_class.find("solar_array")).to be_energy
      expect(described_class.find("shipyard")).not_to be_extraction
    end
  end

  describe ".in_groups" do
    it "splits structures into catalogue-ordered groups" do
      facilities = described_class.in_category("facility").map { |d| OpenStruct.new(definition: d) }

      expect(described_class.in_groups(facilities).map(&:first))
        .to eq([ "Resource processing", "Storage", "Crew support", "Infrastructure" ])
    end

    it "skips groups with no members" do
      solar = [ OpenStruct.new(definition: described_class.find("solar_array")) ]

      expect(described_class.in_groups(solar).map(&:first)).to eq([ "Energy" ])
    end
  end

  it "gives every structure a known group" do
    described_class.all.each do |structure|
      expect(described_class::GROUPS).to have_key(structure.group), "#{structure.key} has group #{structure.group}"
    end
  end

  it "starts every planet with a level for each known structure" do
    expect(described_class::STARTING_LEVELS.keys).to match_array(described_class.keys)
  end
end
