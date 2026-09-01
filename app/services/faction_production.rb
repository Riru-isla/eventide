# What a roused faction does with its war chest.
#
# Fortifying its own garrisons, for now: it needs no movement or combat code, and it is
# the thing a commander feels first — a faction you woke and then walked away from is
# harder when you come back. Ships arrive with raids.
#
# Everything here obeys the rules a commander plays by. Work costs resources, work takes
# ticks, and a faction can only work on as many things at once as it has worlds to work
# from. Its advantages are tempo and scale, never an exemption.
class FactionProduction
  # Metal *and* crystal spent per point of defence added.
  COST_PER_DEFENCE = 8

  # How long fortifying one garrison takes at build speed 1.0 — an `aware` level 1 faction
  # in a standard galaxy. Everything deeper, angrier or in a harsher galaxy is faster.
  FORTIFY_TICKS = 120

  def initialize(galaxy)
    @galaxy = galaxy
  end

  def run!
    complete_finished
    @galaxy.npc_factions.standing.roused.includes(:empire).find_each { |faction| commission(faction) }
  end

  private

  def complete_finished
    projects_here.due_by(@galaxy.current_tick).includes(:system).find_each do |project|
      project.system.increment!(:defense_strength, project.defence_gain)
      project.destroy!
    end
  end

  def projects_here
    FactionProject.where(npc_faction_id: @galaxy.npc_factions.select(:id))
  end

  def commission(faction)
    busy = faction.projects.pluck(:system_id)
    slots = faction.build_slots - busy.size

    slots.times do
      target = next_target(faction, busy)
      break if target.nil?

      gain = faction.fortification_ceiling - target.defense_strength
      cost = gain * COST_PER_DEFENCE
      # Nothing is queued that cannot be paid for outright, the same as a build order.
      break if faction.metal < cost || faction.crystal < cost

      faction.empire.update!(metal: faction.metal - cost, crystal: faction.crystal - cost)
      faction.projects.create!(
        system: target, kind: "fortify", defence_gain: gain,
        started_at_tick: @galaxy.current_tick,
        completes_at_tick: @galaxy.current_tick + duration(faction)
      )
      busy << target.id
    end
  end

  def duration(faction)
    [ (FORTIFY_TICKS / faction.build_speed).round, 1 ].max
  end

  # The garrison nearest to ground a commander holds: a roused faction shores up its front
  # rather than its rear. With nobody near it, it works through whatever is under-built.
  #
  # Capitals are never candidates — they are generated at six times an ordinary garrison
  # and the ceiling is three, so they are already past it.
  def next_target(faction, busy)
    candidates = faction.ordinary_systems.where.not(id: busy)
                        .where(defense_strength: ...faction.fortification_ceiling).to_a
    return nil if candidates.empty?
    return candidates.first if front.empty?

    candidates.min_by { |system| front.map { |x, y| system.distance_to(x, y) }.min }
  end

  def front
    # Commanders only. Every faction is an empire now, so "anything with an owner" would
    # have a faction reinforcing against its own territory.
    @front ||= @galaxy.systems.commanded.pluck(:x, :y)
  end
end
