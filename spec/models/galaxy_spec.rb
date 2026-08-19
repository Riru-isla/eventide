require 'rails_helper'

RSpec.describe Galaxy, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:systems).dependent(:destroy) }
    it { is_expected.to have_many(:sectors).dependent(:destroy) }
    it { is_expected.to have_many(:empires).dependent(:destroy) }
    it { is_expected.to have_many(:npc_factions).dependent(:destroy) }
    it { is_expected.to have_many(:fleets).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:width).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:height).is_greater_than(0) }
  end

  describe "status enum" do
    it "defaults to active" do
      galaxy = described_class.new
      expect(galaxy).to be_active
    end
  end

  describe "sizes" do
    it "reads dimension, garrison budget and sector count from the chosen size" do
      expect(described_class.dimension_for("small")).to eq(150)
      expect(described_class.npc_systems_for("small")).to eq(540)
      expect(described_class.faction_count_for("small")).to eq(11)
    end

    it "offers only the sizes worth playing a campaign in" do
      expect(described_class::PLAYABLE_SIZES).not_to include("tiny")
    end
  end

  describe "#restless?" do
    it "is false when the galaxy waits to be provoked" do
      expect(build(:galaxy, stress_level: "chill")).not_to be_restless
    end

    it "is true when the frontier wakes on its own" do
      expect(build(:galaxy, stress_level: "restless")).to be_restless
    end
  end

  describe "#center" do
    it "returns the integer center coordinate" do
      galaxy = build(:galaxy, width: 21, height: 21)
      expect(galaxy.center).to eq(x: 10, y: 10)
    end
  end

  describe "#radius" do
    it "measures to the nearest edge, since the galaxy is the inscribed disc" do
      expect(build(:galaxy, width: 20, height: 20).radius).to eq(10.0)
    end
  end

  describe "#inside?" do
    subject(:galaxy) { build(:galaxy, width: 20, height: 20) }

    it "accepts the centre and the edge" do
      expect(galaxy.inside?(10, 10)).to be(true)
      expect(galaxy.inside?(0, 10)).to be(true)
    end

    it "rejects the corners, which is the point of using a disc" do
      expect(galaxy.inside?(0, 0)).to be(false)
    end
  end

  describe "#core" do
    it "reports the stored core coordinate" do
      expect(build(:galaxy, core_x: 4, core_y: 9).core).to eq(x: 4, y: 9)
    end
  end

  describe "sector lookups" do
    let(:galaxy) { create(:galaxy) }

    it "finds the core and spawn sectors by kind" do
      core = create(:sector, galaxy: galaxy, kind: "core")
      spawn = create(:sector, galaxy: galaxy, kind: "spawn")
      create(:sector, galaxy: galaxy)

      expect(galaxy.core_sector).to eq(core)
      expect(galaxy.spawn_sector).to eq(spawn)
    end
  end
end
