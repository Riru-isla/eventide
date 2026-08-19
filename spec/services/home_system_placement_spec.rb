require 'rails_helper'

RSpec.describe HomeSystemPlacement, type: :service do
  let(:galaxy) { create(:galaxy, width: 15, height: 15, core_x: 14, core_y: 7) }

  def fill(sector, xs, ys)
    xs.each { |x| ys.each { |y| create(:system, galaxy: galaxy, sector: sector, x: x, y: y, name: "S#{x}-#{y}") } }
  end

  def seat!
    system = described_class.new(galaxy).next_free_system
    system&.update!(kind: "home", empire: create(:empire, galaxy: galaxy))
    system
  end

  describe "#next_free_system" do
    let!(:spawn) { create(:sector, galaxy: galaxy, kind: "spawn", seed_x: 5, seed_y: 5) }

    before { fill(spawn, 0..10, 0..10) }

    it "seats the first commander at the heart of the spawn sector" do
      expect(seat!).to have_attributes(x: 5, y: 5)
    end

    it "keeps the next commander as close to the group as the minimum gap allows" do
      first = seat!
      second = described_class.new(galaxy).next_free_system

      spaced = spawn.systems.reject { |s| s == first }
                    .select { |s| s.distance_to(first.x, first.y) >= described_class::MINIMUM_GAP }

      expect(second.distance_to(first.x, first.y)).to be >= described_class::MINIMUM_GAP
      expect(second.distance_to(5, 5)).to eq(spaced.map { |s| s.distance_to(5, 5) }.min)
    end

    it "never seats anyone outside the spawn sector" do
      elsewhere = create(:sector, galaxy: galaxy, seed_x: 13, seed_y: 13)
      fill(elsewhere, 12..14, 12..14)

      expect(4.times.map { seat!.sector_id }.uniq).to eq([ spawn.id ])
    end

    it "skips systems an NPC faction holds" do
      taken = galaxy.systems.at(5, 5).first
      taken.update!(npc_faction: create(:npc_faction, galaxy: galaxy))

      expect(seat!).not_to eq(taken)
    end

    it "returns nil when nothing is free" do
      faction = create(:npc_faction, galaxy: galaxy)
      galaxy.systems.find_each { |system| system.update!(npc_faction: faction) }

      expect(described_class.new(galaxy).next_free_system).to be_nil
    end
  end

  describe "when the sector is too crowded to keep the gap" do
    let!(:spawn) { create(:sector, galaxy: galaxy, kind: "spawn", seed_x: 1, seed_y: 1) }

    before { fill(spawn, 0..2, 0..2) }

    it "squeezes a commander in rather than turning them away" do
      first = seat!
      second = seat!

      expect(second).to be_present
      expect(second).not_to eq(first)
      # Nothing in a 3x3 sector can respect the gap, so it takes the furthest corner going.
      expect(second.distance_to(first.x, first.y)).to be < described_class::MINIMUM_GAP
    end
  end

  describe "when generation left no spawn sector" do
    before { fill(nil, 0..3, 0..3) }

    it "still seats a commander somewhere free" do
      expect(seat!).to be_present
    end
  end
end
