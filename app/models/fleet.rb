class Fleet < ApplicationRecord
  STATUSES = %w[orbiting moving returning].freeze
  MISSIONS = %w[attack transport].freeze

  # However much Propulsion Technology is stacked, a crossing never takes less than
  # this fraction of its raw distance.
  MINIMUM_TRAVEL_SPEED = 0.4

  belongs_to :empire
  belongs_to :galaxy
  # origin_system is the fleet's home: where it sits while orbiting and where it comes
  # back to. target_system is only set while it is away.
  belongs_to :origin_system, class_name: "System"
  belongs_to :target_system, class_name: "System", optional: true

  scope :moving, -> { where(status: "moving") }
  scope :returning, -> { where(status: "returning") }
  scope :under_way, -> { where(status: %w[moving returning]) }
  # Everything whose next landfall is this system: fleets heading here, and this
  # system's own fleets on their way back.
  scope :bound_for, ->(system) {
    under_way.where(
      "(status = 'moving' AND target_system_id = :id) OR (status = 'returning' AND origin_system_id = :id)",
      id: system.id
    )
  }

  validates :status, inclusion: { in: STATUSES }
  validates :mission, inclusion: { in: MISSIONS }
  validates :ships, presence: true
  validate :cargo_fits_in_the_hold

  def transport? = mission == "transport"

  def under_way? = status != "orbiting"

  def total_ships
    ships.values.sum
  end

  def cargo_load
    cargo.to_h.values.sum(&:to_i)
  end

  def carrying? = cargo_load.positive?

  # Cargo as resource symbols, ignoring anything that is not a stored resource.
  def manifest
    cargo.to_h.filter_map do |resource, amount|
      key = resource.to_sym
      [ key, amount.to_i ] if PlanetEconomy::STORED.include?(key) && amount.to_i.positive?
    end.to_h
  end

  def base_power
    ShipType.each_in(ships).sum { |definition, count| definition.attack * count }
  end

  # How much plunder this fleet can haul out of a captured system.
  def cargo_capacity
    ShipType.each_in(ships).sum { |definition, count| definition.cargo * count }
  end

  # A fleet crosses at the pace of its slowest hull.
  def speed_factor
    factors = ShipType.each_in(ships).map { |definition, _| definition.speed_factor }

    [ factors.max || 1.0, ShipType::MINIMUM_SPEED_FACTOR ].max
  end

  # Ticks to cross between two systems: raw distance, slowed by the heaviest hull
  # aboard and quickened by Propulsion Technology. Never less than a single tick.
  def travel_ticks_between(from, to)
    distance = from.distance_to(to.x, to.y)
    drive = [ 1 - empire.technology_bonus(:propulsion), MINIMUM_TRAVEL_SPEED ].max

    [ (distance * speed_factor * drive).ceil, 1 ].max
  end

  # Weapons and Laser Technology both feed the empire's attack multiplier.
  def power
    (base_power * empire.attack_multiplier).round
  end

  # Applies Armor Technology to a failed attack: some of the fleet limps home instead
  # of the whole force being lost. Returns false when nothing survived.
  def retreat!
    survivors = ships.transform_values { |count| (count * empire.armor_survival).floor }
                     .reject { |_, count| count.zero? }

    return false if survivors.empty?

    update!(ships: survivors, target_system: nil, status: "orbiting", arrival_tick: nil)
    true
  end

  # Sends the fleet back the way it came. origin_system is untouched, so arriving home
  # is simply a matter of clearing the target.
  def turn_for_home!(current_tick, travel_ticks)
    update!(status: "returning", arrival_tick: current_tick + travel_ticks)
  end

  def dock!
    update!(status: "orbiting", target_system: nil, arrival_tick: nil, cargo: {})
  end

  # Ships settling somewhere join the fleet already in orbit there rather than forming
  # a second one. A second orbiting fleet at the same system would strand its ships:
  # the dispatch form, the shipyard and the garrison count all look at the first only.
  def join_garrison!(system = origin_system)
    self.origin_system = system
    existing = empire.fleets.where(origin_system: system, status: "orbiting").where.not(id: id).first
    return dock! if existing.nil?

    merged = existing.ships.dup
    ships.each { |key, count| merged[key] = merged[key].to_i + count.to_i }
    existing.update!(ships: merged)
    destroy!
  end

  private

  def cargo_fits_in_the_hold
    return if cargo_load <= cargo_capacity

    errors.add(:cargo, "of #{cargo_load} exceeds the fleet's hold of #{cargo_capacity}")
  end
end
