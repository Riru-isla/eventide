# A planet's shipyard: what it may build, and the queue of hulls it is building.
#
# Ships need a Shipyard of a given level and, for the heavier hulls, technologies —
# the same gating shape as research, so the two screens read the same way.
class Shipyard
  class Error < StandardError; end

  def initialize(planet)
    @planet = planet
    @empire = planet.empire
    @galaxy = planet.sector.galaxy
  end

  def level
    @planet.level_of("shipyard")
  end

  def operational? = level.positive?

  def orders
    @planet.ship_orders.queued
  end

  def current
    orders.detect(&:building?)
  end

  # Prerequisites not yet met, as readable text. Empty means it can be built.
  def unmet_requirements(definition)
    missing = []
    missing << "Shipyard #{definition.requires_shipyard}" if level < definition.requires_shipyard

    definition.requires.each do |kind, required|
      missing << "#{Technology.find!(kind).name} #{required}" if @empire.technology_level(kind) < required
    end

    missing
  end

  def available?(definition)
    unmet_requirements(definition).empty?
  end

  # The Robotics Bay and Construction Technology speed hulls up too, same as buildings.
  def ticks_for(definition, quantity)
    definition.ticks_for(quantity, speed_multiplier: @planet.economy.build_speed)
  end

  def affordable?(definition, quantity)
    cost = definition.cost(quantity)

    @empire.metal >= cost[:metal] && @empire.crystal >= cost[:crystal] && @empire.crew >= cost[:crew]
  end

  # Charges the empire and queues the batch. Paid up front, as with everything else.
  def enqueue!(kind, quantity)
    definition = ShipType.find(kind)
    raise Error, "unknown ship" if definition.nil?
    raise Error, "quantity must be at least one" if quantity < 1

    missing = unmet_requirements(definition)
    raise Error, "#{definition.name} needs #{missing.to_sentence}" if missing.any?

    ActiveRecord::Base.transaction do
      charge!(definition, quantity)

      order = @planet.ship_orders.create!(
        kind: kind,
        quantity: quantity,
        ticks_required: ticks_for(definition, quantity),
        position: next_position
      )

      start_next!
      order.reload
    end
  end

  # Delivers every batch that has come due into the planet's garrison.
  def advance!
    loop do
      order = @planet.ship_orders.due(@galaxy.current_tick).queued.first
      break if order.nil?

      finished_at = order.completes_at_tick
      deliver!(order)
      start_next!(from_tick: finished_at)
    end

    start_next!
  end

  private

  # Crew is spent, not lent: the hull sails with it, and it is gone from the pool for
  # good. Losing a fleet therefore costs the crew aboard as well as the hulls.
  def charge!(definition, quantity)
    cost = definition.cost(quantity)

    unless affordable?(definition, quantity)
      raise Error, "#{quantity} #{definition.name} needs #{cost[:metal]} metal, " \
                   "#{cost[:crystal]} crystal and #{cost[:crew]} crew"
    end

    @empire.update!(
      metal: @empire.metal - cost[:metal],
      crystal: @empire.crystal - cost[:crystal],
      crew: @empire.crew - cost[:crew]
    )
  end

  # New hulls join the fleet already orbiting the planet, or start a new one.
  def deliver!(order)
    garrison = @empire.fleets.find_by(origin_sector: @planet.sector, status: "orbiting")

    if garrison
      ships = garrison.ships.dup
      ships[order.kind] = ships[order.kind].to_i + order.quantity
      garrison.update!(ships: ships)
    else
      @galaxy.fleets.create!(
        empire: @empire,
        origin_sector: @planet.sector,
        arrival_tick: @galaxy.current_tick,
        status: "orbiting",
        ships: { order.kind => order.quantity }
      )
    end

    order.destroy!
  end

  def start_next!(from_tick: @galaxy.current_tick)
    return if @planet.ship_orders.building.exists?

    @planet.ship_orders.waiting.queued.first&.start!(from_tick)
  end

  def next_position
    (@planet.ship_orders.maximum(:position) || 0) + 1
  end
end
