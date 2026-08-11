# Everything the planet screen needs to show, derived from structure levels.
#
# Output is reported as a list of named contributions that sum to the total, so the
# UI can show *where* a number comes from rather than just the number. Balance work
# should change the numbers here, not the shape.
class PlanetEconomy
  RESOURCES = %i[metal crystal].freeze

  # A planet drawing more energy than it produces keeps this fraction of its output.
  THROTTLE = 0.30

  # However many Robotics Bay levels are stacked, construction never drops below this
  # fraction of its base duration.
  MINIMUM_BUILD_SPEED = 0.25

  Contribution = Struct.new(:label, :value, :kind, keyword_init: true)

  def initialize(planet)
    @planet = planet
    @sector = planet.sector
    @empire = planet.empire
  end

  # ── Energy ────────────────────────────────────────────────────────────────

  # The Warden bonus applies here rather than to a stored resource: energy stopped
  # accumulating, so the role's identity is being able to sustain higher structure
  # levels than anyone else on the same hardware.
  def energy_production
    @energy_production ||= (@planet.structures.sum(&:energy_output) * @empire.resource_bonus(:energy)).round
  end

  def energy_consumption
    @energy_consumption ||= @planet.structures.sum(&:energy_draw)
  end

  def energy_balance
    energy_production - energy_consumption
  end

  def deficit?
    energy_balance.negative?
  end

  # ── Output ────────────────────────────────────────────────────────────────

  def output(resource)
    contributions(resource).sum(&:value).round
  end

  # Ordered contributions that add up to `output(resource)`. The throttle is the
  # last entry so the UI can render it as a deduction.
  def contributions(resource)
    base = base_yield(resource)
    level = @planet.level_of(Structure.extractor_for(resource).key)
    subtotal = base * level

    lines = [
      Contribution.new(label: "Base deposit", value: base.to_f, kind: :base),
      Contribution.new(
        label: "#{Structure.extractor_for(resource).name} lv #{level}",
        value: (subtotal - base).to_f,
        kind: :structure
      ),
      role_contribution(resource, subtotal),
      refinery_contribution(resource, subtotal)
    ]

    if deficit?
      throttled = lines.sum(&:value) * (1 - THROTTLE)
      lines << Contribution.new(label: "Energy deficit", value: -throttled, kind: :throttle)
    end

    lines
  end

  # ── Storage ───────────────────────────────────────────────────────────────

  # Silos sit on the planet but resources are held by the empire. With one planet per
  # empire those are the same thing; this is the seam to revisit for multiple planets.
  def storage_capacity(resource)
    silo = Structure.silo_for(resource)

    silo.storage_capacity(@planet.level_of(silo.key))
  end

  def stored(resource)
    @empire.public_send(resource)
  end

  def storage_fraction(resource)
    (stored(resource).to_f / storage_capacity(resource)).clamp(0.0, 1.0)
  end

  def storage_full?(resource)
    stored(resource) >= storage_capacity(resource)
  end

  # ── Construction ──────────────────────────────────────────────────────────

  # Multiplier applied to build times. The Robotics Bay shortens them; the floor
  # stops high levels from making construction instant.
  def build_speed
    [ 1 - (Structure::BUILD_SPEED_PER_LEVEL * @planet.level_of("robotics_bay")), MINIMUM_BUILD_SPEED ].max
  end

  # ── Structures ────────────────────────────────────────────────────────────

  # Structures in catalogue order, so the screen lists them consistently.
  def structures
    Structure.all.map do |definition|
      @planet.structure(definition.key) ||
        @planet.structures.build(kind: definition.key, level: 0)
    end
  end

  # What the energy balance would become after raising this structure one level.
  def energy_balance_after_upgrade(structure)
    definition = structure.definition
    next_level = structure.level + 1
    delta = (definition.energy_output(next_level) - definition.energy_output(structure.level)) -
            (definition.energy_draw(next_level) - definition.energy_draw(structure.level))

    energy_balance + delta
  end

  def affordable?(structure)
    cost = structure.upgrade_cost

    @empire.metal >= cost[:metal] && @empire.crystal >= cost[:crystal]
  end

  private

  def base_yield(resource)
    resource == :metal ? @sector.metal_rate.to_i : @sector.crystal_rate.to_i
  end

  def role_contribution(resource, subtotal)
    multiplier = @empire.resource_bonus(resource)

    Contribution.new(
      label: "#{@empire.role.capitalize} doctrine",
      value: subtotal * (multiplier - 1),
      kind: :role
    )
  end

  def refinery_contribution(resource, subtotal)
    refinery = Structure.refinery_for(resource)
    levels = @planet.level_of(refinery.key)

    Contribution.new(
      label: "#{refinery.name} lv #{levels}",
      value: subtotal * Structure::YIELD_BONUS_PER_LEVEL * levels,
      kind: :facility
    )
  end
end
