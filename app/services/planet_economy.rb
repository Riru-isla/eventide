# Everything the planet screen needs to show, derived from structure levels.
#
# Output is reported as a list of named contributions that sum to the total, so the
# UI can show *where* a number comes from rather than just the number. Balance work
# should change the numbers here, not the shape.
class PlanetEconomy
  # A planet drawing more energy than it produces keeps this fraction of its output.
  THROTTLE = 0.30

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
    level = @planet.level_of(extractor_key(resource))
    subtotal = base * level

    lines = [
      Contribution.new(label: "Base deposit", value: base.to_f, kind: :base),
      Contribution.new(
        label: "#{Structure.find!(extractor_key(resource)).name} lv #{level}",
        value: (subtotal - base).to_f,
        kind: :structure
      )
    ]

    lines << role_contribution(resource, subtotal)
    lines << refinery_contribution(subtotal) if resource == :metal

    if deficit?
      throttled = lines.sum(&:value) * (1 - THROTTLE)
      lines << Contribution.new(label: "Energy deficit", value: -throttled, kind: :throttle)
    end

    lines
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

  def extractor_key(resource)
    resource == :metal ? "metal_extractor" : "crystal_extractor"
  end

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

  def refinery_contribution(subtotal)
    levels = @planet.level_of("refinery")

    Contribution.new(
      label: "Refinery lv #{levels}",
      value: subtotal * Structure::METAL_BONUS_PER_LEVEL * levels,
      kind: :facility
    )
  end
end
