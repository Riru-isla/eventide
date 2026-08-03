require 'rails_helper'

RSpec.describe GalaxyGenerator, type: :service do
  describe "#generate" do
    let(:player_configs) do
      [
        { name: "Ada", role: "cultivator" },
        { name: "Ben", role: "foundry" }
      ]
    end

    it "creates a galaxy with sectors" do
      galaxy = described_class.new(name: "Test", width: 11, height: 11, player_configs: player_configs).generate

      expect(galaxy).to be_persisted
      expect(galaxy.sectors.count).to eq(121)
      expect(galaxy.name).to eq("Test")
    end

    it "creates NPC factions" do
      galaxy = described_class.new(name: "Test", width: 11, height: 11, player_configs: player_configs).generate
      expect(galaxy.npc_factions.count).to eq(described_class::FACTIONS.size)
    end

    it "creates empires and players" do
      galaxy = described_class.new(name: "Test", width: 11, height: 11, player_configs: player_configs).generate
      expect(galaxy.empires.count).to eq(2)
      expect(Player.count).to eq(2)
    end

    it "places home sectors on the outer rim" do
      galaxy = described_class.new(name: "Test", width: 15, height: 15, player_configs: player_configs).generate
      center = galaxy.center

      galaxy.empires.each do |empire|
        home = empire.home_sector
        expect(home).to be_present
        expect(home.empire).to eq(empire)
        expect(home.distance_to(center[:x], center[:y])).to be > 4
      end
    end

    it "creates a core sector with high defense" do
      galaxy = described_class.new(name: "Test", width: 11, height: 11, player_configs: player_configs).generate
      center = galaxy.center
      core = galaxy.sectors.at(center[:x], center[:y]).first

      expect(core.kind).to eq("core")
      expect(core.defense_strength).to be >= 500
      expect(core.npc_faction).to be_present
    end

    it "creates starting fleets" do
      galaxy = described_class.new(name: "Test", width: 11, height: 11, player_configs: player_configs).generate
      expect(galaxy.fleets.count).to eq(2)
    end
  end
end
