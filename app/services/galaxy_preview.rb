# Draws a generated galaxy as a standalone SVG, so the shape of a run can be looked at
# and the generation constants tuned without starting a server or resetting a session.
#
# Territory is what matters here, so every system is drawn — faintly when it is empty
# space and brightly when somebody garrisons it. That makes the sector boundaries visible
# as colour changes, which is the thing being tuned.
class GalaxyPreview
  BACKGROUND = "#0a0912".freeze
  SPAWN_COLOR = "#eae6f7".freeze
  HOME_COLOR = "#ffffff".freeze

  # Empty space still shows its sector's colour, just quietly, so regions read as regions.
  EMPTY_OPACITY = 0.16
  RESOURCE_OPACITY = 0.30
  HELD_OPACITY = 0.95

  def initialize(galaxy)
    @galaxy = galaxy
  end

  def to_svg
    parts = [ header, disc ]
    parts.concat(system_rects)
    parts.concat(markers)
    parts.concat(labels)
    parts << legend
    parts << "</svg>"
    parts.join("\n")
  end

  # One row per sector, deepest last: what to read alongside the picture when tuning.
  def summary
    @galaxy.sectors.order(:power_level, :name).map do |sector|
      {
        name: sector.name,
        kind: sector.kind,
        power_level: sector.power_level,
        weight: sector.weight.round(2),
        systems: counts_by_sector.fetch(sector.id, 0),
        garrisoned: garrison_by_sector.fetch(sector.id, 0),
        seed: "#{sector.seed_x},#{sector.seed_y}",
        faction: sector.npc_faction&.name
      }
    end
  end

  # What the shape costs a player: how far away the first fight is, and the first capital.
  # This is the pair of numbers the previous concentric-ring design failed on — one player
  # was 40 ticks from the frontier capital and another 117 — so it belongs in front of you
  # whenever the generation constants move.
  def frontier
    garrisons = @galaxy.systems.where.not(npc_faction_id: nil).to_a
    capitals = @galaxy.npc_factions.includes(:capital_system).filter_map(&:capital_system)
    return [] if garrisons.empty? || capitals.empty?

    @galaxy.systems.where(kind: "home").includes(empire: [ :player, :fleets ]).filter_map do |home|
      fleet = home.empire&.fleets&.first
      next if fleet.nil?

      {
        player: home.empire.player.name,
        garrison_ticks: fleet.travel_ticks_between(home, nearest(home, garrisons)),
        capital_ticks: fleet.travel_ticks_between(home, nearest(home, capitals))
      }
    end
  end

  private

  def nearest(home, systems)
    systems.min_by { |system| home.distance_to(system.x, system.y) }
  end

  def dimension = @galaxy.width

  def sectors = @sectors ||= @galaxy.sectors.includes(:npc_faction).index_by(&:id)

  def rows
    @rows ||= @galaxy.systems.pluck(:x, :y, :kind, :sector_id, :npc_faction_id)
  end

  def counts_by_sector
    @counts_by_sector ||= rows.group_by { |row| row[3] }.transform_values(&:size)
  end

  def garrison_by_sector
    @garrison_by_sector ||= rows.select { |row| row[4] }.group_by { |row| row[3] }.transform_values(&:size)
  end

  def colour_for(sector_id)
    @colours ||= sectors.transform_values { |sector| sector.npc_faction&.color || SPAWN_COLOR }
    @colours.fetch(sector_id, SPAWN_COLOR)
  end

  def header
    <<~SVG.strip
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{dimension} #{dimension + 14}"
           width="#{dimension * 6}" height="#{(dimension + 14) * 6}" shape-rendering="crispEdges">
      <rect width="100%" height="100%" fill="#{BACKGROUND}"/>
    SVG
  end

  def disc
    centre = @galaxy.center
    %(<circle cx="#{centre[:x]}" cy="#{centre[:y]}" r="#{@galaxy.radius}" fill="none" ) +
      %(stroke="#2c2650" stroke-width="0.4"/>)
  end

  def system_rects
    rows.map do |x, y, kind, sector_id, faction_id|
      %(<rect x="#{x}" y="#{y}" width="1" height="1" fill="#{fill_for(kind, sector_id)}" ) +
        %(opacity="#{opacity_for(kind, faction_id)}"/>)
    end
  end

  def fill_for(kind, sector_id)
    return HOME_COLOR if kind == "home"

    colour_for(sector_id)
  end

  def opacity_for(kind, faction_id)
    return 1.0 if kind == "home"
    return HELD_OPACITY if faction_id
    return RESOURCE_OPACITY if kind == "resource"

    EMPTY_OPACITY
  end

  # Capitals and the core get a ring so they can be picked out of their own territory.
  def markers
    marks = @galaxy.npc_factions.includes(:capital_system).filter_map do |faction|
      capital = faction.capital_system
      next if capital.nil?

      ring(capital.x, capital.y, faction.sector&.core? ? 4.5 : 2.5, faction.color)
    end

    marks + @galaxy.systems.where(kind: "home").map { |home| ring(home.x, home.y, 2.0, HOME_COLOR) }
  end

  def ring(x, y, radius, colour)
    %(<circle cx="#{x + 0.5}" cy="#{y + 0.5}" r="#{radius}" fill="none" stroke="#{colour}" stroke-width="0.6"/>)
  end

  def labels
    @galaxy.sectors.map do |sector|
      %(<text x="#{sector.seed_x}" y="#{sector.seed_y - 3}" fill="#eae6f7" font-size="2.6" ) +
        %(font-family="monospace" text-anchor="middle" opacity="0.75">) +
        %(#{ERB::Util.html_escape(sector.name)} L#{sector.power_level}</text>)
    end
  end

  def legend
    %(<text x="2" y="#{dimension + 9}" fill="#a49cc4" font-size="3.4" font-family="monospace">) +
      %(#{ERB::Util.html_escape(@galaxy.name)} · #{@galaxy.size} · #{dimension}x#{dimension} · ) +
      %(#{rows.size} systems · #{@galaxy.sectors.count} sectors · core #{@galaxy.core_x},#{@galaxy.core_y}</text>)
  end
end
