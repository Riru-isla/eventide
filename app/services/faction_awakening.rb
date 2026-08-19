# Decides when a faction stops ignoring the players.
#
# The governing principle is **punish recklessness, not slowness**. A clock running from
# tick zero would punish a group for playing two hours a day rather than six, which is the
# one thing that should not cost them. So a faction has no clock at all while every
# neighbour still stands: escalation spreads outward from wherever players are actually
# fighting and can never get ahead of them.
class FactionAwakening
  # How sharply a faction discounts a neighbour's fall the further beneath it that
  # neighbour sat. One level up and it very likely stirs; several levels up and a rim gang
  # dying on its border barely registers.
  GAP_FALLOFF = 0.45

  # What a failed roll leaves of the remaining wait. A faction with no clock starts one at
  # its full delay; one already counting down has the remainder cut, so repeated trouble
  # next door drags it forward even when no single event is enough to rouse it.
  HASTEN = 0.6

  def initialize(galaxy)
    @galaxy = galaxy
  end

  # A player fleet reached one of this faction's systems. Whatever happened next, they know
  # now — otherwise the map is scoutable with total impunity, and flying deep costs nothing.
  def contact!(faction)
    return if faction.nil? || faction.fallen? || faction.roused?

    rouse!(faction)
  end

  # A system changed hands. Only a capital finishes a faction; everything else is ground.
  # A faction dies when its capital is taken rather than when every system it holds is
  # cleared, so each one ends in a battle worth organising for instead of a mop-up.
  def captured!(system, faction)
    return if faction.nil? || faction.fallen? || faction.capital_system_id != system.id

    faction.update!(fallen_at_tick: @galaxy.current_tick)
    faction.neighbours.standing.slumbering.find_each { |neighbour| consider(neighbour, faction) }
  end

  # Anything whose clock has run out is up. Factions with no clock are untouched, which is
  # most of the map for most of a run.
  def advance!
    @galaxy.npc_factions.standing.slumbering
           .where(wake_at_tick: ..@galaxy.current_tick)
           .find_each { |faction| rouse!(faction) }
  end

  private

  # Win the roll and it is up now. Lose and the clock merely *starts* — low awareness means
  # late rather than never, and the next neighbour to fall rolls again, pulling it in.
  def consider(faction, fallen)
    return rouse!(faction) if Random.rand < chance(faction, fallen)

    faction.update!(wake_at_tick: hastened(faction))
  end

  def hastened(faction)
    now = @galaxy.current_tick
    return now + faction.wake_delay if faction.wake_at_tick.nil?

    now + (([ faction.wake_at_tick - now, 0 ].max) * HASTEN).round
  end

  def chance(faction, fallen)
    gap = [ faction.power_level - fallen.power_level, 0 ].max

    (faction.awareness / 100.0) * (GAP_FALLOFF**gap)
  end

  def rouse!(faction)
    faction.update!(aggression: :aware, wake_at_tick: @galaxy.current_tick)
  end
end
