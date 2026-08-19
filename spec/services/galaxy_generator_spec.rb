require 'rails_helper'

RSpec.describe GalaxyGenerator, type: :service do
  let(:player_configs) do
    [
      { name: "Ada", role: "cultivator" },
      { name: "Ben", role: "foundry" }
    ]
  end

  # `tiny` keeps the suite fast; the shape logic is identical at every size. The handful of
  # properties that need more sectors than `tiny` has are checked at `small` below.
  subject(:galaxy) { described_class.new(name: "Test", size: "tiny", player_configs: player_configs).generate }

  # Walks a sector's coordinates as a grid graph. A sector is meant to be pushed into and
  # crossed, so an exclave stranded behind somebody else's border is a defect.
  def contiguous?(cells)
    remaining = cells.to_set
    queue = [ remaining.first ]
    remaining.delete(queue.first)

    until queue.empty?
      x, y = queue.pop
      [ [ 1, 0 ], [ -1, 0 ], [ 0, 1 ], [ 0, -1 ] ].each do |dx, dy|
        neighbour = [ x + dx, y + dy ]
        queue << neighbour if remaining.delete?(neighbour)
      end
    end

    remaining.empty?
  end

  describe "the disc" do
    it "records the size it was built at" do
      expect(galaxy.size).to eq("tiny")
      expect(galaxy.width).to eq(Galaxy.dimension_for("tiny"))
    end

    it "builds no systems outside the disc, so there are no dead corners" do
      outside = galaxy.systems.reject { |system| galaxy.inside?(system.x, system.y) }

      expect(outside).to be_empty
      expect(galaxy.systems.count).to be < (galaxy.width * galaxy.height)
    end

    it "fills the disc it does cover" do
      # Area of the inscribed circle, within a few percent for rounding at the edge.
      expected = Math::PI * (galaxy.radius**2)

      expect(galaxy.systems.count).to be_within(expected * 0.05).of(expected)
    end
  end

  describe "sectors" do
    it "creates the number the size asks for" do
      expect(galaxy.sectors.count).to eq(Galaxy.faction_count_for("tiny") + 1)
    end

    it "gives every sector territory" do
      expect(galaxy.sectors.map { |sector| sector.systems.count }).to all(be_positive)
    end

    it "keeps every territory contiguous" do
      galaxy.sectors.each do |sector|
        expect(contiguous?(sector.systems.pluck(:x, :y))).to be(true), "#{sector.name} is split into exclaves"
      end
    end

    it "has exactly one core sector and one spawn sector" do
      expect(galaxy.sectors.where(kind: "core").count).to eq(1)
      expect(galaxy.sectors.where(kind: "spawn").count).to eq(1)
    end
  end

  describe "the core" do
    it "sits out near the rim rather than at the centre" do
      centre = galaxy.center
      offset = Math.sqrt(((galaxy.core_x - centre[:x])**2) + ((galaxy.core_y - centre[:y])**2))

      expect(offset).to be > (galaxy.radius * 0.5)
    end

    it "stands on its own sector's seed, held by the deepest faction" do
      core = galaxy.systems.at(galaxy.core_x, galaxy.core_y).first

      expect(core.kind).to eq("core")
      expect(core.sector).to eq(galaxy.core_sector)
      expect(core.npc_faction.power_level).to eq(described_class::POWER_LEVELS)
    end

    it "puts the players at the far end of the disc from it" do
      spawn = galaxy.spawn_sector
      span = Math.sqrt(((spawn.seed_x - galaxy.core_x)**2) + ((spawn.seed_y - galaxy.core_y)**2))

      expect(span).to be > galaxy.radius
    end
  end

  describe "power levels" do
    it "rises as sectors near the core" do
      distances = galaxy.sectors.by_power.map(&:distance_to_core)

      expect(distances).to eq(distances.sort.reverse)
    end

    it "garrisons more systems the deeper a faction sits" do
      counts = galaxy.npc_factions.by_power.map { |faction| faction.systems.count }

      expect(counts).to eq(counts.sort)
    end

    it "defends each system harder the deeper a faction sits" do
      strengths = galaxy.npc_factions.by_power.map do |faction|
        faction.systems.where.not(id: faction.capital_system_id).average(:defense_strength).to_f
      end

      expect(strengths).to eq(strengths.sort)
    end

    it "spends roughly the garrison budget the size allows" do
      expect(galaxy.systems.where.not(npc_faction_id: nil).count)
        .to be_within(BUDGET_TOLERANCE).of(Galaxy.npc_systems_for("tiny"))
    end

    BUDGET_TOLERANCE = 6
  end

  describe "capitals" do
    it "gives every faction exactly one, standing on its sector's seed" do
      galaxy.npc_factions.each do |faction|
        capital = faction.capital_system

        expect(capital).to be_present
        expect([ capital.x, capital.y ]).to eq([ faction.sector.seed_x, faction.sector.seed_y ])
      end
    end

    it "keeps a capital inside its own territory, so the sector has to be crossed" do
      galaxy.npc_factions.each do |faction|
        expect(faction.capital_system.sector_id).to eq(faction.sector_id)
      end
    end

    it "makes a capital far tougher than the systems around it" do
      faction = galaxy.npc_factions.by_power.first
      ordinary = faction.systems.where.not(id: faction.capital_system_id).average(:defense_strength)

      expect(faction.capital_system.defense_strength).to be > ordinary * 3
    end

    it "counts a faction as standing while it holds its capital" do
      faction = galaxy.npc_factions.first

      expect(faction).to be_capital_held
      expect(faction).not_to be_fallen
    end
  end

  describe "the spawn sector" do
    it "belongs to nobody and is garrisoned by nobody" do
      spawn = galaxy.spawn_sector

      expect(spawn.npc_faction).to be_nil
      expect(spawn.systems.where.not(npc_faction_id: nil)).to be_empty
    end

    it "holds every commander, so the whole group shares one frontier" do
      homes = galaxy.systems.where(kind: "home")

      expect(homes.count).to eq(2)
      expect(homes.map(&:sector_id).uniq).to eq([ galaxy.spawn_sector.id ])
    end

    it "gives each empire a starting fleet" do
      expect(galaxy.fleets.count).to eq(2)
    end
  end

  describe "aggression" do
    it "wakes only the factions on the rim" do
      rim = galaxy.npc_factions.where(power_level: 1)

      expect(rim).to be_any
      expect(rim.map(&:aggression).uniq).to eq([ "dormant" ])
    end

    it "leaves every deeper faction unaware that players exist" do
      deeper = galaxy.npc_factions.where.not(power_level: 1)

      expect(deeper.map(&:aggression).uniq).to eq([ "unaware" ])
    end
  end

  # These need more sectors than `tiny` has, so they pay for a real generation.
  describe "at a playable size" do
    subject(:galaxy) { described_class.new(name: "Playable", size: "small", player_configs: player_configs).generate }

    it "makes the core sector the largest on the map" do
      # Only meaningful at a real size: on `tiny` the core's reach cap bites hard enough
      # against a 40-wide disc that a neighbour can out-grow it.
      largest = galaxy.sectors.max_by { |sector| sector.systems.count }

      expect(largest).to eq(galaxy.core_sector)
    end

    it "spreads factions across every power level" do
      expect(galaxy.npc_factions.pluck(:power_level).uniq.sort).to eq((1..described_class::POWER_LEVELS).to_a)
    end

    it "puts only the weakest sectors against the spawn, never the core" do
      spawn = galaxy.spawn_sector
      owner = galaxy.systems.pluck(:x, :y, :sector_id).to_h { |x, y, id| [ [ x, y ], id ] }

      bordering = spawn.systems.pluck(:x, :y).flat_map { |x, y|
        [ [ 1, 0 ], [ -1, 0 ], [ 0, 1 ], [ 0, -1 ] ].filter_map do |dx, dy|
          id = owner[[ x + dx, y + dy ]]
          id unless id.nil? || id == spawn.id
        end
      }.uniq

      levels = Sector.where(id: bordering).pluck(:power_level)

      expect(levels).to be_any
      expect(levels.max).to be <= 2
    end
  end
end
