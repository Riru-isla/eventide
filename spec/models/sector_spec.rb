require 'rails_helper'

RSpec.describe Sector, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:galaxy) }
    it { is_expected.to belong_to(:empire).optional }
    it { is_expected.to belong_to(:npc_faction).optional }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:x).only_integer }
    it { is_expected.to validate_numericality_of(:y).only_integer }
    it { is_expected.to validate_inclusion_of(:kind).in_array(Sector::KINDS) }
  end

  describe "#coordinate" do
    it "returns x,y as a string" do
      sector = build(:sector, x: 5, y: 7)
      expect(sector.coordinate).to eq("5,7")
    end
  end

  describe "#distance_to" do
    it "calculates Euclidean distance" do
      sector = build(:sector, x: 0, y: 0)
      expect(sector.distance_to(3, 4)).to eq(5.0)
    end
  end

  describe "#distance_to_center" do
    it "calculates distance to the galaxy center" do
      galaxy = create(:galaxy, width: 11, height: 11)
      sector = create(:sector, galaxy: galaxy, x: 5, y: 5)
      expect(sector.distance_to_center).to eq(0.0)
    end
  end

  describe "#owner_name" do
    it "returns the player name for empire sectors" do
      player = build(:player, name: "Ada")
      empire = build(:empire, player: player)
      sector = build(:sector, empire: empire)
      expect(sector.owner_name).to eq("Ada")
    end

    it "returns the faction name for NPC sectors" do
      faction = build(:npc_faction, name: "Void Hegemony")
      sector = build(:sector, npc_faction: faction)
      expect(sector.owner_name).to eq("Void Hegemony")
    end

    it "returns Unclaimed for empty sectors" do
      sector = build(:sector)
      expect(sector.owner_name).to eq("Unclaimed")
    end
  end
end
