require 'rails_helper'

RSpec.describe GalaxyGenerator, type: :service do
  let(:player_configs) do
    [
      { name: "Ada", role: "cultivator" },
      { name: "Ben", role: "foundry" }
    ]
  end

  # `tiny` keeps the suite fast; the band and tier logic is identical at every size.
  subject(:galaxy) { described_class.new(name: "Test", size: "tiny", player_configs: player_configs).generate }

  describe "the grid" do
    it "fills every coordinate of the chosen size" do
      expect(galaxy.width).to eq(Galaxy.dimension_for("tiny"))
      expect(galaxy.sectors.count).to eq(galaxy.width * galaxy.height)
    end

    it "records the size it was built at" do
      expect(galaxy.size).to eq("tiny")
    end

    it "builds a core sector at the centre, held by the deepest faction" do
      centre = galaxy.center
      core = galaxy.sectors.at(centre[:x], centre[:y]).first

      expect(core.kind).to eq("core")
      expect(core.npc_faction.tier).to eq(described_class::TIERS.last[:tier])
    end
  end

  describe "faction tiers" do
    it "creates one faction per tier" do
      expect(galaxy.npc_factions.by_tier.map(&:tier)).to eq(described_class::TIERS.map { |t| t[:tier] })
    end

    it "puts the weakest faction furthest out and the strongest at the core" do
      # The previous generator had this inverted: the weakest faction held the ring
      # next to the core.
      distances = galaxy.npc_factions.by_tier.map do |faction|
        faction.sectors.map(&:distance_to_center).min
      end

      expect(distances).to eq(distances.sort.reverse)
    end

    it "holds more sectors the closer to the core a faction sits" do
      counts = galaxy.npc_factions.by_tier.map { |faction| faction.sectors.count }

      expect(counts).to eq(counts.sort)
    end

    it "defends more heavily the closer to the core a faction sits" do
      defences = galaxy.npc_factions.by_tier.map do |faction|
        faction.sectors.where.not(id: faction.capital_sector_id).average(:defense_strength).to_f
      end

      expect(defences).to eq(defences.sort)
    end

    it "spreads a faction through the depth of its band rather than one ring" do
      faction = galaxy.npc_factions.by_tier.last
      distances = faction.sectors.map(&:distance_to_center)

      expect(distances.max - distances.min).to be > 1.0
    end

    it "holds the budgeted number of sectors in total" do
      expect(galaxy.sectors.where.not(npc_faction_id: nil).count)
        .to be_within(TIERS_TOLERANCE).of(Galaxy.npc_sectors_for("tiny") + 1) # +1 for the core
    end

    TIERS_TOLERANCE = 5
  end

  describe "capitals" do
    it "gives every faction exactly one capital" do
      galaxy.npc_factions.each do |faction|
        expect(faction.capital_sector).to be_present
        expect(faction.capital_sector.npc_faction_id).to eq(faction.id)
      end
    end

    it "makes a capital far tougher than the sectors around it" do
      faction = galaxy.npc_factions.by_tier.first
      ordinary = faction.sectors.where.not(id: faction.capital_sector_id).average(:defense_strength)

      expect(faction.capital_sector.defense_strength).to be > ordinary * 3
    end

    it "counts a faction as standing while it holds its capital" do
      faction = galaxy.npc_factions.first

      expect(faction).to be_capital_held
      expect(faction).not_to be_fallen
    end
  end

  describe "aggression" do
    it "wakes only the outermost faction" do
      expect(galaxy.npc_factions.find_by(tier: 1).aggression).to eq("dormant")
    end

    it "leaves every deeper faction unaware that players exist" do
      deeper = galaxy.npc_factions.where.not(tier: 1)

      expect(deeper.map(&:aggression).uniq).to eq([ "unaware" ])
    end

    it "reports the outermost standing faction as the frontier" do
      expect(galaxy.frontier_faction.tier).to eq(1)
    end
  end

  describe "players" do
    it "creates an empire and planet per config" do
      expect(galaxy.empires.count).to eq(2)
      expect(galaxy.empires.map(&:planet)).to all(be_present)
    end

    it "spawns them out on the rim, clear of every faction band" do
      innermost_npc = galaxy.sectors.where.not(npc_faction_id: nil).map(&:distance_to_center).max

      galaxy.empires.each do |empire|
        expect(empire.home_sector.distance_to_center).to be > innermost_npc
      end
    end

    it "leaves the outer band free of NPCs" do
      outer = galaxy.sectors.select { |s| s.distance_to_center > galaxy.radius * (1 - described_class::PLAYER_BAND) }

      expect(outer.map(&:npc_faction_id).compact).to be_empty
    end

    it "gives each empire a starting fleet" do
      expect(galaxy.fleets.count).to eq(2)
    end
  end
end
