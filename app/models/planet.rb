class Planet < ApplicationRecord
  # Held by a commander or by a faction, never both and never neither.
  belongs_to :empire, optional: true
  belongs_to :npc_faction, optional: true
  belongs_to :system
  has_many :structures, class_name: "PlanetStructure", dependent: :destroy
  has_many :build_orders, dependent: :destroy
  has_many :ship_orders, dependent: :destroy

  validates :name, presence: true
  validate :held_by_exactly_one_owner

  # One planet per empire for now. Lifting this is deliberately a one-line change:
  # nothing else in the model assumes a single planet. Factions are not limited this way —
  # infrastructure spread across a territory is the point of theirs.
  validates :empire_id, uniqueness: { message: "already has a planet" }, if: :empire_id?

  def owner
    empire || npc_faction
  end

  # Hulls of one kind sitting in the fleet orbiting this planet.
  def garrison_count(ship_key)
    empire.fleets.detect { |fleet| fleet.origin_system_id == system_id && fleet.status == "orbiting" }
          &.ships&.fetch(ship_key, 0).to_i
  end

  def structure(key)
    structures.detect { |record| record.kind == key }
  end

  def level_of(key)
    structure(key)&.level.to_i
  end

  def economy
    @economy ||= PlanetEconomy.new(self)
  end

  def queue
    @queue ||= BuildQueue.new(self)
  end

  def shipyard
    @shipyard ||= Shipyard.new(self)
  end

  # These helpers cache the planet's state, including the galaxy's current tick, so
  # they have to go when the record is reloaded or they answer with stale numbers.
  def reload(...)
    @economy = nil
    @queue = nil
    @shipyard = nil
    super
  end

  private

  def held_by_exactly_one_owner
    return if empire_id.present? ^ npc_faction_id.present?

    errors.add(:base, "a planet belongs to one empire or one faction")
  end
end
