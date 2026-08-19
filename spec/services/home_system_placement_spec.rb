require 'rails_helper'

RSpec.describe HomeSystemPlacement, type: :service do
  describe "#next_free_system" do
    let(:galaxy) { create(:galaxy, width: 15, height: 15) }

    before do
      (0...15).each do |y|
        (0...15).each do |x|
          create(:system, galaxy: galaxy, x: x, y: y, name: "System #{x}-#{y}")
        end
      end
    end

    it "places the first empire on the ring around the core" do
      system = described_class.new(galaxy).next_free_system

      expect(system.distance_to_center).to be > 4
    end

    it "spreads consecutive empires apart instead of clustering them" do
      first = described_class.new(galaxy).next_free_system
      first.update!(empire: create(:empire, galaxy: galaxy))

      second = described_class.new(galaxy).next_free_system

      expect(second).not_to eq(first)
      expect(second.distance_to(first.x, first.y)).to be > 4
    end

    it "skips ring slots held by an NPC faction" do
      taken = described_class.new(galaxy).next_free_system
      taken.update!(npc_faction: create(:npc_faction, galaxy: galaxy))

      expect(described_class.new(galaxy).next_free_system).not_to eq(taken)
    end

    it "falls back to the free system furthest from the core when the ring is full" do
      faction = create(:npc_faction, galaxy: galaxy)
      galaxy.systems.find_each { |system| system.update!(npc_faction: faction) }

      corner = galaxy.systems.at(0, 0).first
      corner.update!(npc_faction: nil)

      expect(described_class.new(galaxy).next_free_system).to eq(corner)
    end

    it "returns nil when no system is free" do
      faction = create(:npc_faction, galaxy: galaxy)
      galaxy.systems.find_each { |system| system.update!(npc_faction: faction) }

      expect(described_class.new(galaxy).next_free_system).to be_nil
    end
  end
end
