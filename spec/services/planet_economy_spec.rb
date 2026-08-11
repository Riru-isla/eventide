require 'rails_helper'

RSpec.describe PlanetEconomy, type: :service do
  let(:galaxy) { create(:galaxy) }
  let(:empire) { create(:empire, galaxy: galaxy, role: "foundry") }
  let(:sector) { create(:sector, galaxy: galaxy, metal_rate: 30, crystal_rate: 20) }
  let(:planet) { Planet.create!(empire: empire, sector: sector, name: "Test World") }

  def build_structure(kind, level)
    planet.structures.create!(kind: kind, level: level)
  end

  def economy
    PlanetEconomy.new(planet.reload)
  end

  describe "energy" do
    it "sums production and draw across structures" do
      build_structure("solar_array", 9)        # +900
      build_structure("metal_extractor", 12)   # -408
      build_structure("shipyard", 3)           # -60

      expect(economy.energy_production).to eq(900)
      expect(economy.energy_consumption).to eq(468)
      expect(economy.energy_balance).to eq(432)
      expect(economy).not_to be_deficit
    end

    it "gives wardens more energy from the same structures" do
      build_structure("solar_array", 4)
      empire.update!(role: "warden")

      expect(economy.energy_production).to eq((400 * 1.5).round)
    end

    it "reports a deficit when draw exceeds production" do
      build_structure("solar_array", 1)        # +100
      build_structure("metal_extractor", 5)    # -170

      expect(economy.energy_balance).to eq(-70)
      expect(economy).to be_deficit
    end
  end

  describe "#contributions" do
    before do
      build_structure("solar_array", 20)       # ample energy, no throttle
      build_structure("metal_extractor", 3)
      build_structure("refinery", 2)
    end

    it "breaks the total into contributions that sum to the output" do
      lines = economy.contributions(:metal)

      expect(lines.map(&:label)).to eq([
        "Base deposit",
        "Metal Extractor lv 3",
        "Foundry doctrine",
        "Metal Refinery lv 2",
        "Extraction Technology lv 0"
      ])
      expect(lines.sum(&:value).round).to eq(economy.output(:metal))
    end

    it "credits researched extraction technology in the breakdown" do
      empire.technologies.create!(kind: "extraction_technology", level: 4)

      line = economy.contributions(:metal).detect { |entry| entry.kind == :research }

      expect(line.label).to eq("Extraction Technology lv 4")
      expect(line.value).to eq(90 * 0.05 * 4) # 20% of the 90 raw subtotal
    end

    it "computes each contribution from the sector, level, role, and refinery" do
      values = economy.contributions(:metal).map { |line| line.value.round }

      # base 30, +60 from levels 2-3, +50% foundry on 90, +20% refinery on 90, no research
      expect(values).to eq([ 30, 60, 45, 18, 0 ])
      expect(economy.output(:metal)).to eq(153)
    end

    it "credits each resource to its own refinery" do
      expect(economy.contributions(:metal).map(&:label)).to include("Metal Refinery lv 2")
      expect(economy.contributions(:crystal).map(&:label)).to include("Crystal Refinery lv 0")
    end

    it "adds a crystal refinery bonus to crystal only" do
      build_structure("crystal_extractor", 3)
      build_structure("crystal_refinery", 4)

      crystal = economy.contributions(:crystal).detect { |line| line.label.start_with?("Crystal Refinery") }
      metal = economy.contributions(:metal).detect { |line| line.label.start_with?("Metal Refinery") }

      expect(crystal.label).to eq("Crystal Refinery lv 4")
      expect(crystal.value).to be_positive
      expect(metal.label).to eq("Metal Refinery lv 2")
    end
  end

  describe "throttling" do
    before do
      build_structure("solar_array", 1)        # +100
      build_structure("metal_extractor", 5)    # -170 -> deficit
    end

    it "adds a deficit line that cuts output to the throttle fraction" do
      lines = economy.contributions(:metal)

      expect(lines.last.label).to eq("Energy deficit")
      expect(lines.last.value).to be_negative
    end

    it "leaves the planet with the throttle fraction of its output" do
      undeflected = economy.contributions(:metal).reject { |line| line.kind == :throttle }.sum(&:value)

      expect(economy.output(:metal)).to eq((undeflected * described_class::THROTTLE).round)
    end
  end

  describe "storage" do
    it "gives a planet with no silo the base capacity" do
      expect(economy.storage_capacity(:metal)).to eq(Structure::BASE_STORAGE)
    end

    it "raises capacity with silo level, per resource" do
      build_structure("metal_silo", 3)

      expect(economy.storage_capacity(:metal)).to be > Structure::BASE_STORAGE
      expect(economy.storage_capacity(:crystal)).to eq(Structure::BASE_STORAGE)
    end

    it "reports how full a store is" do
      empire.update!(metal: Structure::BASE_STORAGE / 4)

      expect(economy.storage_fraction(:metal)).to eq(0.25)
      expect(economy).not_to be_storage_full(:metal)
    end

    it "clamps the fraction when a store is over capacity" do
      empire.update!(metal: Structure::BASE_STORAGE * 10)

      expect(economy.storage_fraction(:metal)).to eq(1.0)
      expect(economy).to be_storage_full(:metal)
    end
  end

  describe "#structures" do
    it "returns one entry per catalogue structure, in catalogue order" do
      build_structure("metal_extractor", 4)

      expect(economy.structures.map(&:kind)).to eq(Structure.keys)
    end

    it "reports level zero for structures that have not been built" do
      expect(economy.structures.detect { |s| s.kind == "refinery" }.level).to eq(0)
    end
  end

  describe "#energy_balance_after_upgrade" do
    before do
      build_structure("solar_array", 2)        # +200
      build_structure("metal_extractor", 5)    # -170, balance +30
    end

    it "subtracts the extra draw of a consumer" do
      extractor = economy.structures.detect { |s| s.kind == "metal_extractor" }

      expect(economy.energy_balance_after_upgrade(extractor)).to eq(30 - 34)
    end

    it "adds the extra output of a generator" do
      solar = economy.structures.detect { |s| s.kind == "solar_array" }

      expect(economy.energy_balance_after_upgrade(solar)).to eq(30 + 100)
    end
  end

  describe "#affordable?" do
    before { build_structure("refinery", 0) }

    it "is true when the empire can pay" do
      empire.update!(metal: 10_000, crystal: 10_000)

      expect(economy.affordable?(economy.structures.detect { |s| s.kind == "refinery" })).to be true
    end

    it "is false when the empire cannot" do
      empire.update!(metal: 0, crystal: 0)

      expect(economy.affordable?(economy.structures.detect { |s| s.kind == "refinery" })).to be false
    end
  end
end
