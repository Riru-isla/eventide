require 'rails_helper'

RSpec.describe Sector, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:galaxy) }
    it { is_expected.to have_many(:systems).dependent(:nullify) }
    it { is_expected.to have_one(:npc_faction).dependent(:nullify) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:weight).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:power_level).only_integer.is_greater_than(0) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
  end

  describe "kinds" do
    it "reports which sector holds the core and which holds the players" do
      expect(build(:sector, kind: "core")).to be_core
      expect(build(:sector, kind: "spawn")).to be_spawn
      expect(build(:sector, kind: "standard")).not_to be_core
      expect(build(:sector, kind: "standard")).not_to be_spawn
    end
  end

  describe ".holdable" do
    it "excludes the players' sector, which no faction may hold" do
      galaxy = create(:galaxy)
      standard = create(:sector, galaxy: galaxy, kind: "standard")
      core = create(:sector, galaxy: galaxy, kind: "core")
      create(:sector, galaxy: galaxy, kind: "spawn")

      expect(described_class.holdable).to contain_exactly(standard, core)
    end
  end

  describe "#seed_system" do
    it "finds the system standing on the seed, which is where a capital goes" do
      galaxy = create(:galaxy)
      sector = create(:sector, galaxy: galaxy, seed_x: 3, seed_y: 4)
      seed = create(:system, galaxy: galaxy, sector: sector, x: 3, y: 4)
      create(:system, galaxy: galaxy, sector: sector, x: 9, y: 9)

      expect(sector.seed_system).to eq(seed)
    end
  end

  describe "#distance_to_core" do
    it "measures its seed against the galaxy core" do
      galaxy = create(:galaxy, core_x: 0, core_y: 0)
      sector = create(:sector, galaxy: galaxy, seed_x: 3, seed_y: 4)

      expect(sector.distance_to_core).to eq(5.0)
    end
  end
end
