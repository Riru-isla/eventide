require 'rails_helper'

RSpec.describe Planet, type: :model do
  let(:galaxy) { create(:galaxy) }
  let(:empire) { create(:empire, galaxy: galaxy) }
  let(:sector) { create(:sector, galaxy: galaxy) }

  describe "associations" do
    it { is_expected.to belong_to(:empire) }
    it { is_expected.to belong_to(:sector) }
    it { is_expected.to have_many(:structures).dependent(:destroy) }
  end

  describe "validations" do
    subject { described_class.new(empire: empire, sector: sector, name: "World") }

    it { is_expected.to validate_presence_of(:name) }

    it "allows only one planet per empire" do
      described_class.create!(empire: empire, sector: sector, name: "First")
      second = described_class.new(empire: empire, sector: create(:sector, galaxy: galaxy), name: "Second")

      expect(second).not_to be_valid
      expect(second.errors[:empire_id]).to include("already has a planet")
    end
  end

  describe "#level_of" do
    let(:planet) { described_class.create!(empire: empire, sector: sector, name: "World") }

    it "returns the level of a built structure" do
      planet.structures.create!(kind: "solar_array", level: 4)

      expect(planet.level_of("solar_array")).to eq(4)
    end

    it "returns zero for a structure that does not exist" do
      expect(planet.level_of("refinery")).to eq(0)
    end
  end

  describe "#economy" do
    let(:planet) { described_class.create!(empire: empire, sector: sector, name: "World") }

    it "memoizes the calculator" do
      expect(planet.economy).to be_a(PlanetEconomy)
      expect(planet.economy).to equal(planet.economy)
    end
  end
end
