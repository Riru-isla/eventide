module GalaxiesHelper
  # Distinct hues that hold up against the indigo ground and do not collide with the
  # NPC faction reds.
  EMPIRE_COLORS = [ "#79d2e2", "#57be8e", "#f5b841", "#e879b8", "#a9b6cc" ].freeze

  UNOWNED_COLORS = {
    "core" => "#ef4444",
    "resource" => "#57be8e",
    "home" => "#eae6f7"
  }.freeze
  EMPTY_COLOR = "#3b3560".freeze

  # Leaves room for the spiral arms to sweep past the outermost sectors.
  MAP_VIEWBOX = 1000
  MAP_RADIUS = 470

  def empire_color(index)
    EMPIRE_COLORS[index % EMPIRE_COLORS.size]
  end

  # Takes a prebuilt {empire_id => colour} map rather than looking the empire up, which
  # is what previously made this run a query for every sector on the map.
  def sector_color(sector, empire_colors)
    return empire_colors.fetch(sector.empire_id, EMPTY_COLOR) if sector.empire_id
    return sector.npc_faction.color if sector.npc_faction

    UNOWNED_COLORS.fetch(sector.kind, EMPTY_COLOR)
  end

  # Grid coordinates placed on the galaxy disc, centred on the core. Scaled so the
  # furthest corner still sits inside the disc.
  def sector_position(sector, galaxy)
    centre = galaxy.center
    span = corner_distance(galaxy)
    scale = MAP_RADIUS / span
    middle = MAP_VIEWBOX / 2.0

    [
      (middle + ((sector.x - centre[:x]) * scale)).round(1),
      (middle + ((sector.y - centre[:y]) * scale)).round(1)
    ]
  end

  # How prominent a sector is: owned worlds and the core read louder than empty space.
  def sector_radius(sector)
    case sector.kind
    when "core" then 13
    when "home" then 10
    when "fortress" then 8
    else sector.empire_id ? 9 : 6
    end
  end

  private

  def corner_distance(galaxy)
    centre = galaxy.center
    Math.sqrt((centre[:x]**2) + (centre[:y]**2)).nonzero? || 1.0
  end
end
