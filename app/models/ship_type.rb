# Static catalogue of every hull an empire can build, in the same spirit as Structure
# and Technology: balance numbers live in code with specs, not in a table.
#
# Fleets store counts keyed by `key`, never by `name`, so a hull can be renamed without
# orphaning every fleet holding one.
#
# Every stat here is used somewhere:
#   attack       — fleet combat power
#   cargo        — how much can be hauled out of a captured sector
#   speed_factor — travel time; a fleet moves at the pace of its slowest hull
class ShipType
  # A fleet never crosses faster than this fraction of raw distance, whatever it holds.
  MINIMUM_SPEED_FACTOR = 0.5

  attr_reader :key, :name, :summary, :attack, :cargo, :speed_factor,
              :metal_cost, :crystal_cost, :crew_cost, :build_ticks,
              :requires_shipyard, :requires

  def initialize(key:, name:, summary:, attack:, cargo:, speed_factor:,
                 metal_cost:, crystal_cost:, crew_cost:, build_ticks:,
                 requires_shipyard: 1, requires: {})
    @key = key
    @name = name
    @summary = summary
    @attack = attack
    @cargo = cargo
    @speed_factor = speed_factor
    @metal_cost = metal_cost
    @crystal_cost = crystal_cost
    @crew_cost = crew_cost
    @build_ticks = build_ticks
    @requires_shipyard = requires_shipyard
    @requires = requires.freeze
  end

  ALL = [
    new(
      key: "light_fighter", name: "Light Fighter",
      summary: "Cheap, quick, and expendable. The hull every empire starts throwing at the rim.",
      attack: 5, cargo: 20, speed_factor: 1.0,
      metal_cost: 30, crystal_cost: 10, crew_cost: 1, build_ticks: 1,
      requires_shipyard: 1
    ),
    new(
      key: "transport", name: "Transport",
      summary: "Unarmed hauler. Carries plunder home from a captured sector, but slows a fleet down.",
      attack: 1, cargo: 500, speed_factor: 1.4,
      metal_cost: 60, crystal_cost: 60, crew_cost: 5, build_ticks: 2,
      requires_shipyard: 2, requires: { "propulsion_technology" => 1 }
    ),
    new(
      key: "medium_fighter", name: "Medium Fighter",
      summary: "A proper gun platform. Three times the punch of a light hull for a little more metal.",
      attack: 15, cargo: 40, speed_factor: 0.9,
      metal_cost: 80, crystal_cost: 30, crew_cost: 2, build_ticks: 2,
      requires_shipyard: 2, requires: { "weapons_technology" => 2 }
    ),
    new(
      key: "heavy_fighter", name: "Heavy Fighter",
      summary: "Armoured line hull. Slower than a medium, but survives what a medium does not.",
      attack: 40, cargo: 80, speed_factor: 1.1,
      metal_cost: 200, crystal_cost: 80, crew_cost: 6, build_ticks: 4,
      requires_shipyard: 4, requires: { "armor_technology" => 2 }
    ),
    new(
      key: "battle_cruiser", name: "Battle Cruiser",
      summary: "Capital ship. Enormously expensive, and worth a whole squadron of fighters.",
      attack: 120, cargo: 200, speed_factor: 1.3,
      metal_cost: 600, crystal_cost: 300, crew_cost: 25, build_ticks: 8,
      requires_shipyard: 6, requires: { "laser_technology" => 1 }
    )
  ].freeze

  BY_KEY = ALL.index_by(&:key).freeze
  KEYS = ALL.map(&:key).freeze

  class << self
    def all = ALL
    def keys = KEYS
    def find(key) = BY_KEY[key]
    def find!(key) = BY_KEY.fetch(key)

    # Ships stored in a fleet, as [definition, count] pairs. Unknown keys are skipped
    # so a retired hull cannot break a fleet that still holds one.
    def each_in(ships)
      return to_enum(:each_in, ships) unless block_given?

      ships.each do |key, count|
        definition = find(key)
        yield definition, count.to_i if definition
      end
    end
  end

  def cost(quantity)
    { metal: metal_cost * quantity, crystal: crystal_cost * quantity, crew: crew_cost * quantity }
  end

  def ticks_for(quantity, speed_multiplier: 1.0)
    [ (build_ticks * quantity * speed_multiplier).ceil, 1 ].max
  end

  # Prerequisites as readable text, for the locked state on the shipyard screen.
  def requirement_labels
    [ "Shipyard #{requires_shipyard}" ] +
      requires.map { |key, level| "#{Technology.find!(key).name} #{level}" }
  end
end
