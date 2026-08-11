# Manages a planet's construction queue: adding orders, starting the next one, and
# applying finished ones.
#
# Resources are charged when an order is queued, not when it finishes, so a player
# cannot queue more than they can pay for.
class BuildQueue
  class Error < StandardError; end

  def initialize(planet)
    @planet = planet
    @galaxy = planet.sector.galaxy
  end

  def orders
    @planet.build_orders.queued
  end

  def current
    orders.detect(&:building?)
  end

  # Prerequisites not yet met, as readable text. Empty means it can be built.
  def unmet_requirements(definition)
    structures = definition.requires_structure.filter_map do |key, level|
      "#{Structure.find!(key).name} #{level}" if @planet.level_of(key) < level
    end

    technologies = definition.requires_tech.filter_map do |key, level|
      "#{Technology.find!(key).name} #{level}" if @planet.empire.technology_level(key) < level
    end

    structures + technologies
  end

  def queued_level_for(kind)
    orders.select { |order| order.kind == kind }.map(&:target_level).max
  end

  # Adds an upgrade to the back of the queue, charging the empire up front.
  def enqueue!(kind)
    definition = Structure.find(kind)
    raise Error, "unknown structure" if definition.nil?

    missing = unmet_requirements(definition)
    raise Error, "#{definition.name} needs #{missing.to_sentence}" if missing.any?

    ActiveRecord::Base.transaction do
      structure = @planet.structures.find_or_create_by!(kind: kind) { |record| record.level = 0 }
      from_level = queued_level_for(kind) || structure.level
      cost = definition.upgrade_cost(from_level)

      charge!(definition, from_level, cost)

      order = @planet.build_orders.create!(
        kind: kind,
        target_level: from_level + 1,
        ticks_required: definition.build_ticks(from_level, speed_multiplier: @planet.economy.build_speed),
        position: next_position
      )

      start_next!
      # start_next! may have started this very order through a different instance,
      # so reload before handing it back or completes_at_tick reads as nil.
      order.reload
    end
  end

  # Applies every order that has come due, starting the next one each time so a queue
  # can advance by more than one step in a single tick.
  def advance!
    loop do
      order = @planet.build_orders.due(@galaxy.current_tick).queued.first
      break if order.nil?

      finished_at = order.completes_at_tick
      apply!(order)
      # The next order picks up from when this one actually finished rather than from
      # now, so a queue does not lose time when the server was down or a tick ran late.
      start_next!(from_tick: finished_at)
    end

    start_next!
  end

  private

  def empire = @planet.empire

  def charge!(definition, from_level, cost)
    if empire.metal < cost[:metal] || empire.crystal < cost[:crystal]
      raise Error, "#{definition.name} level #{from_level + 1} needs " \
                   "#{cost[:metal]} metal and #{cost[:crystal]} crystal"
    end

    empire.update!(metal: empire.metal - cost[:metal], crystal: empire.crystal - cost[:crystal])
  end

  def apply!(order)
    structure = @planet.structures.find_or_create_by!(kind: order.kind) { |record| record.level = 0 }
    structure.update!(level: order.target_level)
    order.destroy!
    @planet.association(:structures).reset
  end

  def start_next!(from_tick: @galaxy.current_tick)
    return if @planet.build_orders.building.exists?

    @planet.build_orders.waiting.queued.first&.start!(from_tick)
  end

  def next_position
    (@planet.build_orders.maximum(:position) || 0) + 1
  end
end
