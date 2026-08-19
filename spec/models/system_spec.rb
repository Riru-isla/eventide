require 'rails_helper'

RSpec.describe System, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:galaxy) }
    it { is_expected.to belong_to(:empire).optional }
    it { is_expected.to belong_to(:npc_faction).optional }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:x).only_integer }
    it { is_expected.to validate_numericality_of(:y).only_integer }
    it { is_expected.to validate_inclusion_of(:kind).in_array(System::KINDS) }
  end

  describe "#coordinate" do
    it "returns x,y as a string" do
      system = build(:system, x: 5, y: 7)
      expect(system.coordinate).to eq("5,7")
    end
  end

  describe "#distance_to" do
    it "calculates Euclidean distance" do
      system = build(:system, x: 0, y: 0)
      expect(system.distance_to(3, 4)).to eq(5.0)
    end
  end

  describe "#distance_to_core" do
    it "measures from the core rather than the middle of the grid" do
      galaxy = create(:galaxy, width: 11, height: 11, core_x: 9, core_y: 5)

      expect(create(:system, galaxy: galaxy, x: 9, y: 5).distance_to_core).to eq(0.0)
      expect(create(:system, galaxy: galaxy, x: 5, y: 5).distance_to_core).to eq(4.0)
    end
  end

  describe "#owner_name" do
    it "returns the player name for empire systems" do
      player = build(:player, name: "Ada")
      empire = build(:empire, player: player)
      system = build(:system, empire: empire)
      expect(system.owner_name).to eq("Ada")
    end

    it "returns the faction name for NPC systems" do
      faction = build(:npc_faction, name: "Void Hegemony")
      system = build(:system, npc_faction: faction)
      expect(system.owner_name).to eq("Void Hegemony")
    end

    it "returns Unclaimed for empty systems" do
      system = build(:system)
      expect(system.owner_name).to eq("Unclaimed")
    end
  end
end
