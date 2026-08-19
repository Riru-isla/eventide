# Builds a session's galaxy: the disc, the sectors it is carved into, the factions that
# hold them, and the players who start out at the far end.
#
# The shape exists to answer one failure of the previous design. Concentric faction bands
# gave a faction no interior — you skirted a ring and hunted for one coordinate somewhere
# on a 880-system circumference, and the faction gating everyone's progress could sit two
# hours of travel from half the players. Sectors are grown from seed points instead, so
# each faction is an irregular contiguous territory you push into and cross.
#
# The core sits out near the rim rather than in the middle. With a central core each
# player only ever cares about the wedge between their spawn and the centre; the corners
# and the far side go unvisited. From the rim, the whole disc lies between the players and
# the objective.
class GalaxyGenerator
  # ── Shape ───────────────────────────────────────────────────────────────────────
  #
  # How far out the core sits, as a fraction of the radius, at a random bearing per
  # galaxy so no two runs are "head southwest".
  CORE_POSITION = 0.72

  # The players' sector is placed deliberately, directly opposite the core. Picking
  # whichever seed happened to land furthest away instead put it hard against the rim,
  # where the disc boundary clipped most of its territory away.
  SPAWN_POSITION = 0.70

  # ── Sector weights ──────────────────────────────────────────────────────────────
  #
  # A seed claims the systems for which `distance / weight` is smallest, so weight is
  # region size. The core sector is deliberately the largest on the map, and sectors grow
  # as they near it.
  CORE_WEIGHT = 1.8

  # How far the core sector may reach from its seed, as a fraction of the distance from
  # the players to the core. Weight alone made it the biggest sector on the map, which is
  # wanted, but also let it sweep around everything else and border the spawn — no amount
  # of seeding in between reliably stopped that, so it is capped outright.
  CORE_REACH = 0.45

  # No other seed may sit within this fraction of the core's reach. The cap that stops the
  # core sector touching the spawn also lets neighbouring seeds crowd it, and without this
  # the largest sector on the map was only the largest in about three runs out of four.
  CORE_SPACING = 0.35
  MIN_WEIGHT = 0.75
  MAX_WEIGHT = 1.6
  WEIGHT_JITTER = 0.12

  # Seeds laid down before anything is scattered, so a campaign always has a spine: a
  # ladder of sectors on the direct line from the players to the core, and an arc across
  # the face they look out on.
  #
  # Without it the core sector — by far the heaviest on the map — sweeps around the rim
  # and ends up bordering the spawn, so a brand new commander can wander into
  # 2,800-defence systems twenty ticks from home. The corridor alone did not stop it;
  # the core simply went round the side.
  CORRIDOR_JITTER = 0.14
  ARC_BEARING = 1.0
  ARC_DISTANCE = 0.45

  # A candidate seed is rejected if it lands nearer than this to one already placed,
  # measured against the spacing an even scatter would give. Without it, two seeds land on
  # top of each other and one sector comes out a sliver.
  SEPARATION = 0.62
  # Spacing relaxes every this many rejections, so placement always terminates with the
  # full count rather than quietly returning fewer sectors than asked for.
  RELAX_AFTER = 60
  RELAX_BY = 0.94

  POWER_LEVELS = 5

  # One corridor seed per level below the core's, so the direct route has a full ladder.
  CORRIDOR_STEPS = POWER_LEVELS - 1

  # How many factions sit at each power level, as a share of the total, weighted toward
  # the rim so a campaign opens wide and narrows to one final enemy.
  #
  # Levels are handed out by *rank* of distance to the core rather than by bucketing raw
  # distance. Seeds scatter unevenly, and bucketing left whole runs with no level 1
  # faction to open on and no level 4 at all — a cliff straight from level 3 to the core.
  LEVEL_SHAPE = [ 0.30, 0.25, 0.20, 0.15, 0.10 ].freeze

  # Base garrison strength of an ordinary system, by power level.
  DEFENCE = [ 60, 160, 420, 1_100, 2_800 ].freeze

  # Relative garrison size of a single faction at each power level, normalised against the
  # whole map so the totals still land on the budget.
  #
  # Weights rather than a share of the budget per level: how many factions land at a given
  # level varies from run to run, and splitting a fixed share between them made a lone rim
  # faction garrison 43 systems while each of the four behind it held 16. Difficulty
  # compounds — deeper factions hold more systems *and* defend each one harder.
  GARRISON_WEIGHT = [ 1.0, 1.8, 3.2, 5.5, 12.0 ].freeze

  # Cold and drab out on the rim, hot at the core, so the map reads as a difficulty ramp
  # at a glance. Several factions share a level, hence a few shades of each.
  LEVEL_COLORS = [
    %w[#6b7f9e #7d92b2 #5a6c88 #8a9cb8],
    %w[#4f9d8a #5fb3a0 #3f8574 #6cc4b0],
    %w[#c9a227 #dcb63c #b08e18 #e6c65a],
    %w[#e07b39 #f0904e #c9682a #f5a76b],
    %w[#dc2626 #ef4444 #b91c1c #f87171]
  ].freeze

  CAPITAL_DEFENCE_MULTIPLIER = 6

  # Base spread of how readily a faction reacts to what happens next door, before the
  # galaxy's awareness level scales it. The spread is the point: two factions at the same
  # power level should not respond identically, so no two runs play out the same way.
  AWARENESS_RANGE = 20..80
  CORE_FACTION_NAME = "Core Imperium".freeze
  SPAWN_SECTOR_NAME = "The Shoals".freeze
  CORE_SECTOR_NAME = "The Nexus".freeze

  SECTOR_NAMES = %w[
    Vela Carina Lyra Orion Draco Perseus Cygnus Auriga Hydra Corvus
    Serpens Tucana Volans Pictor Norma Cepheus Lupus Mensa Crux Dorado
    Fornax Grus Indus Reticulum Sculptor Vulpecula Ophiuchus Antlia
  ].freeze
  SECTOR_SUFFIXES = %w[Reach Expanse Verge Drift Span Shelf].freeze

  FACTION_PREFIXES = %w[Rim Iron Void Crimson Ashen Hollow Pale Storm Dust Cinder Onyx Ember].freeze
  FACTION_SUFFIXES = %w[Marauders Covenant Hegemony Pact Concord Dominion Syndicate Legion Compact Ascendancy].freeze

  # Rows written per INSERT. A large galaxy is ~125,000 systems; one statement each would
  # take minutes.
  BATCH_SIZE = 2_000

  def initialize(name:, size: "small", faction_count: nil, victory_condition: "reach_the_core",
                 team_count: 1, threat_level: "standard", awareness_level: "standard",
                 player_configs: [])
    @name = name
    @size = size.to_s
    @dimension = Galaxy.dimension_for(@size)
    @npc_systems = Galaxy.npc_systems_for(@size)
    @faction_count = faction_count || Galaxy.faction_count_for(@size)
    # One sector per faction, plus the players'.
    @sector_count = @faction_count + 1
    @victory_condition = victory_condition
    @team_count = team_count
    @threat = Galaxy::THREAT_LEVELS.fetch(threat_level)
    @awareness = Galaxy::AWARENESS_LEVELS.fetch(awareness_level)
    @settings = { victory_condition: victory_condition, team_count: team_count,
                  threat_level: threat_level, awareness_level: awareness_level }
    @player_configs = player_configs
  end

  def generate
    galaxy = nil

    ActiveRecord::Base.transaction do
      galaxy = create_galaxy
      sectors = create_sectors(galaxy)
      owner = assign_cells(galaxy, sectors)
      record_borders(sectors, owner)
      cells = group_cells(owner, sectors.size)
      factions = create_factions(galaxy, sectors)
      create_systems(galaxy, sectors, cells, factions)
      assign_capitals(galaxy, sectors, factions)
      create_players_and_empires(galaxy)
    end

    galaxy
  end

  private

  def create_galaxy
    galaxy = Galaxy.new(
      name: @name, size: @size,
      width: @dimension, height: @dimension,
      current_tick: 0, status: :active,
      faction_count: @faction_count, **@settings
    )

    centre = galaxy.center
    bearing = Random.rand * 2 * Math::PI
    galaxy.core_x = (centre[:x] + (CORE_POSITION * galaxy.radius * Math.cos(bearing))).round.clamp(0, @dimension - 1)
    galaxy.core_y = (centre[:y] + (CORE_POSITION * galaxy.radius * Math.sin(bearing))).round.clamp(0, @dimension - 1)
    galaxy.save!

    galaxy
  end

  # Sectors, in the order their seeds were placed: the core, then the players, then the
  # rest scattered through the disc between them. Everybody shares a single spawn sector,
  # so the whole group has one frontier rather than a private one each.
  def create_sectors(galaxy)
    core = core_point(galaxy)
    points = seed_points(galaxy)
    span = distance(points[1], core).nonzero? || 1.0
    levels = power_levels(points, core)
    names = sector_names(points.size)

    points.each_with_index.map do |(x, y), index|
      kind = sector_kind(index)

      galaxy.sectors.create!(
        name: sector_name(kind, names, index),
        seed_x: x, seed_y: y,
        weight: sector_weight(kind, 1.0 - (distance([ x, y ], core) / span)),
        kind: kind,
        power_level: levels[index]
      )
    end
  end

  # The core is always the deepest level and the players always the shallowest; everything
  # between is ranked and dealt out according to LEVEL_SHAPE.
  #
  # Ranked by how far along the line from the players to the core a sector sits, rather
  # than by raw distance to either end. A sector out on the flank is a long way from the
  # spawn while having made no progress inward at all, and by spawn distance it was handed
  # a high level for it — which pushed levels 3 and 4 off the direct path entirely, so
  # walking straight at the core crossed 1, then 2, then the core itself.
  def power_levels(points, core)
    levels = Array.new(points.size)
    levels[0] = POWER_LEVELS
    levels[1] = 1
    spawn = points[1]
    quota = level_counts(points.size - 2)

    # The corridor *is* the ladder: it takes one slot at each rank, in order, so the direct
    # route from the players to the core crosses a sector of every level. Ranking every
    # sector together by progress does not give that — a flank sector at a similar depth
    # takes the slot instead and the route skips a rung.
    corridor = (2...(2 + [ CORRIDOR_STEPS, points.size - 2 ].min)).to_a
    corridor.each_with_index do |index, step|
      levels[index] = step + 1
      quota[step] = [ quota[step] - 1, 0 ].max
    end

    level = 1
    taken = 0

    ((2 + corridor.size)...points.size).sort_by { |index| axis_progress(points[index], spawn, core) }.each do |index|
      while taken >= quota[level - 1] && level < POWER_LEVELS
        level += 1
        taken = 0
      end

      levels[index] = level
      taken += 1
    end

    levels
  end

  # 0 at the players, 1 at the core, measured along the line between them. Sideways
  # distance does not count, which is the whole point.
  def axis_progress(point, spawn, core)
    ax = core[0] - spawn[0]
    ay = core[1] - spawn[1]
    length = ((ax * ax) + (ay * ay)).nonzero? || 1
    # to_f on the numerator, not on the result: every term here is an integer, so dividing
    # first truncates every sector to 0 and the ranking silently does nothing.
    (((point[0] - spawn[0]) * ax) + ((point[1] - spawn[1]) * ay)).to_f / length
  end

  def level_counts(count)
    return Array.new(POWER_LEVELS) { |index| index < count ? 1 : 0 } if count <= POWER_LEVELS

    counts = LEVEL_SHAPE.map { |share| [ (share * count).round, 1 ].max }
    # Rounding drifts by a seat or two; the rim absorbs it.
    counts[0] += count - counts.sum
    counts
  end

  def sector_kind(index)
    return "core" if index.zero?
    return "spawn" if index == 1

    "standard"
  end

  def sector_name(kind, names, index)
    return CORE_SECTOR_NAME if kind == "core"
    return SPAWN_SECTOR_NAME if kind == "spawn"

    names[index]
  end

  def sector_weight(kind, depth)
    return CORE_WEIGHT if kind == "core"

    base = MIN_WEIGHT + ((MAX_WEIGHT - MIN_WEIGHT) * depth)
    base * (1.0 + ((Random.rand - 0.5) * 2 * WEIGHT_JITTER))
  end

  # Seed placement by rejection sampling. The core and the players are placed first, at
  # opposite ends of the disc, and everything else is scattered into the space between
  # them — which is what makes the regions irregular. A stratified scatter would come out
  # as distorted bands, which is the shape this design exists to avoid.
  def seed_points(galaxy)
    core = core_point(galaxy)
    spawn = spawn_point(galaxy)
    reach = distance(spawn, core)
    keep_clear = CORE_SPACING * CORE_REACH * reach
    points = [ core, spawn ]
    # A small galaxy has fewer sectors than the spine wants seeds, and the spine must not
    # be allowed to overshoot the count that was asked for.
    points.concat(spine_points(galaxy, core, spawn, keep_clear).take(@sector_count - points.size))
    spacing = (2 * galaxy.radius * SEPARATION) / Math.sqrt(@sector_count)
    rejections = 0

    while points.size < @sector_count
      candidate = random_point_in_disc(galaxy)

      # Seeds are confined to the ground between the two ends. Further from the core than
      # the players are, and the weakest sectors land *behind* the spawn, so the first
      # fight is a detour rather than progress. Further from the players than the core is,
      # and a sector ends up stranded behind the core where nobody pushing for the middle
      # would ever go — which is how a level 5 faction came to sit somewhere players would
      # never meet it.
      too_far = distance(candidate, core) > reach || distance(candidate, spawn) > reach
      crowded = points.any? { |point| distance(point, candidate) < spacing }
      smothering = distance(candidate, core) < keep_clear

      if too_far || crowded || smothering
        rejections += 1
        spacing *= RELAX_BY if (rejections % RELAX_AFTER).zero?
        next
      end

      points << candidate
    end

    points
  end

  def spine_points(galaxy, core, spawn, keep_clear)
    corridor_points(galaxy, core, spawn, keep_clear) + arc_points(galaxy, core, spawn)
  end

  # Two seeds off either shoulder of the spawn, between the players and the core.
  def arc_points(galaxy, core, spawn)
    span = distance(spawn, core)
    bearing = Math.atan2(core[1] - spawn[1], core[0] - spawn[0])

    [ -ARC_BEARING, ARC_BEARING ].map do |offset|
      reach = ARC_DISTANCE * span

      [
        (spawn[0] + (reach * Math.cos(bearing + offset))).round.clamp(0, @dimension - 1),
        (spawn[1] + (reach * Math.sin(bearing + offset))).round.clamp(0, @dimension - 1)
      ]
    end
  end

  # Laid between the players and the edge of the ground the core keeps clear, so the chain
  # fills the path without any link of it crowding the core sector.
  def corridor_points(galaxy, core, spawn, keep_clear)
    steps = CORRIDOR_STEPS
    span = distance(spawn, core).nonzero? || 1.0
    across = [ (core[1] - spawn[1]) / span, -(core[0] - spawn[0]) / span ]
    usable = [ (span - keep_clear) / span, 0.0 ].max

    (1..steps).map do |step|
      along = (step.to_f / (steps + 1)) * usable
      drift = (Random.rand - 0.5) * 2 * CORRIDOR_JITTER * galaxy.radius

      [
        (spawn[0] + ((core[0] - spawn[0]) * along) + (across[0] * drift)).round.clamp(0, @dimension - 1),
        (spawn[1] + ((core[1] - spawn[1]) * along) + (across[1] * drift)).round.clamp(0, @dimension - 1)
      ]
    end
  end

  # Directly opposite the core, so the whole disc lies between the players and what they
  # are pushing toward.
  def spawn_point(galaxy)
    centre = galaxy.center
    bearing = Math.atan2(galaxy.core_y - centre[:y], galaxy.core_x - centre[:x]) + Math::PI

    [
      (centre[:x] + (SPAWN_POSITION * galaxy.radius * Math.cos(bearing))).round.clamp(0, @dimension - 1),
      (centre[:y] + (SPAWN_POSITION * galaxy.radius * Math.sin(bearing))).round.clamp(0, @dimension - 1)
    ]
  end

  # Uniform over the disc's *area*. Without the square root, points bunch toward the
  # middle and the rim comes out empty.
  def random_point_in_disc(galaxy)
    centre = galaxy.center
    reach = galaxy.radius * Math.sqrt(Random.rand)
    bearing = Random.rand * 2 * Math::PI

    [
      (centre[:x] + (reach * Math.cos(bearing))).round.clamp(0, @dimension - 1),
      (centre[:y] + (reach * Math.sin(bearing))).round.clamp(0, @dimension - 1)
    ]
  end

  # Every disc coordinate handed to the sector whose seed claims it: a flat grid of sector
  # indices, nil outside the disc.
  def assign_cells(galaxy, sectors)
    owner = voronoi_owners(galaxy, sectors)
    absorb_exclaves(owner, sectors)

    owner
  end

  # The same grid grouped by sector, so garrisons can be sampled from within a territory.
  def group_cells(owner, count)
    buckets = Array.new(count) { [] }

    owner.each_with_index do |index, position|
      buckets[index] << [ position % @dimension, position / @dimension ] unless index.nil?
    end

    buckets
  end

  # Which sectors touch which, read straight off the ownership grid by comparing each
  # coordinate with its eastern and southern neighbour. Stored both ways round so a
  # sector's neighbours are one query.
  #
  # Waking spreads across this graph and nowhere else, which is what keeps escalation from
  # getting ahead of where players have actually pushed.
  def record_borders(sectors, owner)
    pairs = Set.new

    (0...@dimension).each do |y|
      (0...@dimension).each do |x|
        here = owner[(y * @dimension) + x]
        next if here.nil?

        [ [ 1, 0 ], [ 0, 1 ] ].each do |dx, dy|
          next if (x + dx) >= @dimension || (y + dy) >= @dimension

          there = owner[((y + dy) * @dimension) + (x + dx)]
          pairs << [ here, there ].minmax unless there.nil? || there == here
        end
      end
    end

    rows = pairs.flat_map do |one, other|
      [ { sector_id: sectors[one].id, neighbour_id: sectors[other].id },
        { sector_id: sectors[other].id, neighbour_id: sectors[one].id } ]
    end

    rows.each_slice(BATCH_SIZE) { |slice| SectorBorder.insert_all!(slice) }
  end

  # Squared distance over squared weight rather than distance over weight: the comparison
  # is identical and it saves a square root per coordinate per seed, in a loop that runs
  # a few million times on a large galaxy.
  def voronoi_owners(galaxy, sectors)
    seed_xs = sectors.map(&:seed_x)
    seed_ys = sectors.map(&:seed_y)
    inverse = sectors.map { |sector| 1.0 / (sector.weight**2) }
    reach = reach_limits(sectors)
    centre = galaxy.center
    limit = galaxy.radius**2
    owner = Array.new(@dimension * @dimension)

    (0...@dimension).each do |y|
      (0...@dimension).each do |x|
        next if (((x - centre[:x])**2) + ((y - centre[:y])**2)) > limit

        owner[(y * @dimension) + x] = nearest_seed(x, y, seed_xs, seed_ys, inverse, reach)
      end
    end

    owner
  end

  # Squared distance beyond which a seed stops competing. Only the core is capped; every
  # other sector is unbounded, so a coordinate always finds an owner.
  def reach_limits(sectors)
    core = sectors.find(&:core?)
    spawn = sectors.find(&:spawn?)
    span = distance([ core.seed_x, core.seed_y ], [ spawn.seed_x, spawn.seed_y ])

    sectors.map { |sector| sector.core? ? (CORE_REACH * span)**2 : Float::INFINITY }
  end

  def nearest_seed(x, y, seed_xs, seed_ys, inverse, reach)
    best = 0
    best_score = Float::INFINITY

    seed_xs.each_index do |index|
      dx = x - seed_xs[index]
      dy = y - seed_ys[index]
      squared = (dx * dx) + (dy * dy)
      next if squared > reach[index]

      score = squared * inverse[index]

      if score < best_score
        best_score = score
        best = index
      end
    end

    best
  end

  # Weighting the seeds is what makes regions organic rather than polygonal, but it also
  # lets a heavy seed's region split into detached lobes when a lighter seed sits between
  # them. An exclave breaks the premise: a sector is meant to be pushed into and crossed,
  # not found in patches stranded behind somebody else's border.
  #
  # So each sector is reduced to the component holding its own seed, and everything left
  # over is grown into from the settled regions outward — which means every coordinate
  # ends up next to one already belonging to the same sector.
  def absorb_exclaves(owner, sectors)
    settled = Array.new(owner.size, false)
    frontier = []

    sectors.each_with_index do |sector, index|
      claim_component(owner, settled, frontier, (sector.seed_y * @dimension) + sector.seed_x, index)
    end

    cursor = 0
    while cursor < frontier.size
      position = frontier[cursor]
      cursor += 1

      each_neighbour(position) do |neighbour|
        next if owner[neighbour].nil? || settled[neighbour]

        owner[neighbour] = owner[position]
        settled[neighbour] = true
        frontier << neighbour
      end
    end
  end

  def claim_component(owner, settled, frontier, start, index)
    owner[start] = index
    settled[start] = true
    stack = [ start ]

    until stack.empty?
      position = stack.pop
      frontier << position

      each_neighbour(position) do |neighbour|
        next if settled[neighbour] || owner[neighbour] != index

        settled[neighbour] = true
        stack << neighbour
      end
    end
  end

  def each_neighbour(position)
    x = position % @dimension
    y = position / @dimension

    yield(position - 1) if x.positive?
    yield(position + 1) if x < @dimension - 1
    yield(position - @dimension) if y.positive?
    yield(position + @dimension) if y < @dimension - 1
  end

  # One faction per sector, except the players'.
  #
  # Only the factions whose territory actually touches the spawn begin knowing players
  # exist, with a clock already running — otherwise nothing would ever have a reason to
  # stir and the galaxy would sleep forever. Everything behind them is `unaware` and has no
  # clock at all until a neighbour falls.
  def create_factions(galaxy, sectors)
    names = faction_names(sectors.size)
    frontier = sectors.find(&:spawn?).neighbours.pluck(:id).to_set

    sectors.reject(&:spawn?).each_with_index.to_h do |sector, index|
      faction = galaxy.npc_factions.new(
        sector: sector,
        name: sector.core? ? CORE_FACTION_NAME : names[index],
        color: LEVEL_COLORS[sector.power_level - 1][index % LEVEL_COLORS.first.size],
        power_level: sector.power_level,
        strength_level: sector.power_level,
        tech_level: sector.power_level,
        aggression: frontier.include?(sector.id) ? :dormant : :unaware,
        awareness: (Random.rand(AWARENESS_RANGE) * @awareness).round.clamp(1, 100)
      )
      faction.wake_at_tick = faction.wake_delay if frontier.include?(sector.id)
      faction.save!

      [ sector.id, faction ]
    end
  end

  def create_systems(galaxy, sectors, buckets, factions)
    now = Time.current
    garrisons = garrison_cells(sectors, buckets, factions)
    rows = []

    sectors.each_with_index do |sector, index|
      faction = factions[sector.id]
      held = garrisons[sector.id]

      buckets[index].each do |x, y|
        rows << if x == galaxy.core_x && y == galaxy.core_y
          core_system(galaxy, sector, faction, x, y, now)
        elsif held.include?([ x, y ])
          npc_system(galaxy, sector, faction, x, y, now)
        else
          open_system(galaxy, sector, x, y, now)
        end
      end
    end

    rows.each_slice(BATCH_SIZE) { |slice| System.insert_all!(slice) }
  end

  # Which coordinates each faction actually garrisons: its budget, drawn from anywhere in
  # its own territory. The seed is always included, so the capital that gets placed on it
  # sits at the heart of the region rather than on an edge — you cross the sector to reach
  # it instead of clipping a corner.
  def garrison_cells(sectors, buckets, factions)
    holders = sectors.reject { |sector| factions[sector.id].nil? }
    total = holders.sum { |sector| GARRISON_WEIGHT[sector.power_level - 1] }

    sectors.each_with_index.to_h do |sector, index|
      next [ sector.id, Set.new ] if factions[sector.id].nil?

      share = GARRISON_WEIGHT[sector.power_level - 1] / total
      budget = [ (@npc_systems * share).round, 1 ].max
      seed = [ sector.seed_x, sector.seed_y ]

      [ sector.id, (buckets[index].sample(budget - 1) << seed).to_set ]
    end
  end

  def npc_system(galaxy, sector, faction, x, y, now)
    defence = (DEFENCE[sector.power_level - 1] * @threat).round

    base_system(galaxy, sector, x, y, now).merge(
      kind: "outpost",
      npc_faction_id: faction.id,
      metal_rate: 20 + (sector.power_level * 12),
      crystal_rate: 20 + (sector.power_level * 12),
      energy_rate: 0,
      defense_strength: defence + Random.rand(defence / 4)
    )
  end

  def open_system(galaxy, sector, x, y, now)
    # Richer deposits nearer the core, so pushing inward is worth it for more than just
    # arriving.
    richness = (depth_at(galaxy, x, y) * 30).round
    resource = Random.rand < 0.25

    base_system(galaxy, sector, x, y, now).merge(
      kind: resource ? "resource" : "empty",
      npc_faction_id: nil,
      metal_rate: resource ? richness + 10 : (richness / 3),
      crystal_rate: resource ? richness + 10 : (richness / 3),
      energy_rate: 0,
      defense_strength: 0
    )
  end

  def core_system(galaxy, sector, faction, x, y, now)
    base_system(galaxy, sector, x, y, now).merge(
      kind: "core",
      npc_faction_id: faction.id,
      metal_rate: 200, crystal_rate: 200, energy_rate: 0,
      defense_strength: (DEFENCE.last * @threat * CAPITAL_DEFENCE_MULTIPLIER).round
    )
  end

  def base_system(galaxy, sector, x, y, now)
    {
      galaxy_id: galaxy.id, sector_id: sector.id, x: x, y: y,
      name: "#{sector.name} #{x}-#{y}", created_at: now, updated_at: now
    }
  end

  # 1.0 at the core, 0.0 at the point of the disc furthest from it.
  def depth_at(galaxy, x, y)
    span = galaxy.radius * (1 + CORE_POSITION)

    1.0 - (distance([ x, y ], core_point(galaxy)) / span).clamp(0.0, 1.0)
  end

  # A capital sits on its sector's seed — the deepest point of the territory — and is far
  # tougher than anything around it. It is the objective that ends the sector: a faction
  # dies when its capital falls, not when every system it holds is cleared.
  def assign_capitals(galaxy, sectors, factions)
    sectors.each do |sector|
      faction = factions[sector.id]
      next if faction.nil?

      capital = galaxy.systems.at(sector.seed_x, sector.seed_y).first
      next if capital.nil?

      unless sector.core?
        capital.update!(
          kind: "fortress",
          defense_strength: capital.defense_strength * CAPITAL_DEFENCE_MULTIPLIER
        )
      end

      faction.update!(capital_system: capital)
    end
  end

  def create_players_and_empires(galaxy)
    @player_configs.each do |config|
      user = User.create!(
        username: config[:username] || config[:name].downcase,
        password: config[:password] || "eventide"
      )

      EmpireFounder.new(galaxy: galaxy, user: user, name: config[:name], role: config[:role]).call
    end
  end

  def sector_names(count)
    SECTOR_NAMES.shuffle.take(count).each_with_index.map do |name, index|
      "#{name} #{SECTOR_SUFFIXES[index % SECTOR_SUFFIXES.size]}"
    end
  end

  def faction_names(count)
    FACTION_PREFIXES.product(FACTION_SUFFIXES).shuffle.take(count).map { |prefix, suffix| "#{prefix} #{suffix}" }
  end

  def core_point(galaxy)
    [ galaxy.core_x, galaxy.core_y ]
  end

  def distance(one, other)
    Math.sqrt(((one[0] - other[0])**2) + ((one[1] - other[1])**2))
  end
end
