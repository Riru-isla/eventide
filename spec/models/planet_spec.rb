require 'rails_helper'

RSpec.describe Planet, type: :model do
  let(:galaxy) { create(:galaxy) }
  let(:empire) { create(:empire, galaxy: galaxy) }
  let(:system) { create(:system, galaxy: galaxy) }

  describe "associations" do
    it { is_expected.to belong_to(:empire).optional }
    it { is_expected.to belong_to(:npc_faction).optional }
    it { is_expected.to belong_to(:system) }
    it { is_expected.to have_many(:structures).dependent(:destroy) }
  end

  describe "validations" do
    subject { described_class.new(empire: empire, system: system, name: "World") }

    it { is_expected.to validate_presence_of(:name) }

    it "allows only one planet per empire" do
      described_class.create!(empire: empire, system: system, name: "First")
      second = described_class.new(empire: empire, system: create(:system, galaxy: galaxy), name: "Second")

      expect(second).not_to be_valid
      expect(second.errors[:empire_id]).to include("already has a planet")
    end
  end

  describe "#level_of" do
    let(:planet) { described_class.create!(empire: empire, system: system, name: "World") }

    it "returns the level of a built structure" do
      planet.structures.create!(kind: "solar_array", level: 4)

      expect(planet.level_of("solar_array")).to eq(4)
    end

    it "returns zero for a structure that does not exist" do
      expect(planet.level_of("refinery")).to eq(0)
    end
  end

  describe "#economy" do
    let(:planet) { described_class.create!(empire: empire, system: system, name: "World") }

    it "memoizes the calculator" do
      expect(planet.economy).to be_a(PlanetEconomy)
      expect(planet.economy).to equal(planet.economy)
    end
  end

  describe "ownership" do
    let(:galaxy) { create(:galaxy) }
    let(:system) { create(:system, galaxy: galaxy) }

    it "may be held by a faction instead of a commander" do
      faction = create(:npc_faction, galaxy: galaxy)
      planet = described_class.new(npc_faction: faction, system: system, name: "Forge")

      expect(planet).to be_valid
      expect(planet.owner).to eq(faction)
    end

    it "refuses to belong to nobody" do
      planet = described_class.new(system: system, name: "Orphan")

      expect(planet).not_to be_valid
      expect(planet.errors[:base]).to include(/one empire or one faction/)
    end

    it "refuses to belong to both" do
      planet = described_class.new(empire: create(:empire, galaxy: galaxy),
                                   npc_faction: create(:npc_faction, galaxy: galaxy),
                                   system: system, name: "Contested")

      expect(planet).not_to be_valid
    end

    it "still allows a faction more than one, unlike a commander" do
      faction = create(:npc_faction, galaxy: galaxy)
      described_class.create!(npc_faction: faction, system: system, name: "Forge")
      second = described_class.new(npc_faction: faction, system: create(:system, galaxy: galaxy), name: "Yard")

      expect(second).to be_valid
    end
  end
end
