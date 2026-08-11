require 'rails_helper'

RSpec.describe HomeSectorPlacement, type: :service do
  describe "#next_free_sector" do
    let(:galaxy) { create(:galaxy, width: 15, height: 15) }

    before do
      (0...15).each do |y|
        (0...15).each do |x|
          create(:sector, galaxy: galaxy, x: x, y: y, name: "Sector #{x}-#{y}")
        end
      end
    end

    it "places the first empire on the ring around the core" do
      sector = described_class.new(galaxy).next_free_sector

      expect(sector.distance_to_center).to be > 4
    end

    it "spreads consecutive empires apart instead of clustering them" do
      first = described_class.new(galaxy).next_free_sector
      first.update!(empire: create(:empire, galaxy: galaxy))

      second = described_class.new(galaxy).next_free_sector

      expect(second).not_to eq(first)
      expect(second.distance_to(first.x, first.y)).to be > 4
    end

    it "skips ring slots held by an NPC faction" do
      taken = described_class.new(galaxy).next_free_sector
      taken.update!(npc_faction: create(:npc_faction, galaxy: galaxy))

      expect(described_class.new(galaxy).next_free_sector).not_to eq(taken)
    end

    it "falls back to the free sector furthest from the core when the ring is full" do
      faction = create(:npc_faction, galaxy: galaxy)
      galaxy.sectors.find_each { |sector| sector.update!(npc_faction: faction) }

      corner = galaxy.sectors.at(0, 0).first
      corner.update!(npc_faction: nil)

      expect(described_class.new(galaxy).next_free_sector).to eq(corner)
    end

    it "returns nil when no sector is free" do
      faction = create(:npc_faction, galaxy: galaxy)
      galaxy.sectors.find_each { |sector| sector.update!(npc_faction: faction) }

      expect(described_class.new(galaxy).next_free_sector).to be_nil
    end
  end
end
