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
        "Refinery lv 2"
      ])
      expect(lines.sum(&:value).round).to eq(economy.output(:metal))
    end

    it "computes each contribution from the sector, level, role, and refinery" do
      values = economy.contributions(:metal).map { |line| line.value.round }

      # base 30, +60 from levels 2-3, +50% foundry on 90, +20% refinery on 90
      expect(values).to eq([ 30, 60, 45, 18 ])
      expect(economy.output(:metal)).to eq(153)
    end

    it "omits the refinery line for crystal" do
      labels = economy.contributions(:crystal).map(&:label)

      expect(labels).not_to include(a_string_matching(/Refinery/))
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
