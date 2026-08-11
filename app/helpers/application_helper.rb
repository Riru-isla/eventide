module ApplicationHelper
  # Signed figures read better in a HUD: "+78" and "−102" rather than "78"/"-102".
  # Uses a real minus sign so digits stay aligned in tabular columns.
  def number_with_sign(value)
    rounded = value.round
    sign = rounded.negative? ? "−" : "+"

    "#{sign}#{number_with_delimiter(rounded.abs)}"
  end

  # Tailwind only generates classes it finds as literal strings, so these are written
  # out in full rather than interpolated from the resource name.
  def resource_tone(resource)
    case resource
    when :metal then "text-metal"
    when :crystal then "text-crystal"
    else "text-good"
    end
  end

  def resource_bar_tone(resource)
    case resource
    when :metal then "bg-metal"
    when :crystal then "bg-crystal"
    else "bg-good"
    end
  end

  def structure_glyph_tone(definition)
    return "text-amber" if definition.energy?
    return "text-ink-2" if definition.resource.nil?

    resource_tone(definition.resource)
  end

  # One line saying what a structure is currently doing for the planet, phrased per
  # effect so a row reads the same way whatever kind of structure it is.
  def structure_effect_summary(definition, level, economy)
    case definition.effect
    when :extraction then "#{number_with_sign(economy.output(definition.resource))} #{definition.resource} / tick"
    when :energy then "#{number_with_sign(economy.energy_production)} energy"
    when :yield_bonus then "#{yield_bonus_percent(level)} #{definition.resource} yield"
    when :crew_training then "#{number_with_sign(definition.crew_per_level * level)} crew / tick"
    when :defence then "#{number_with_delimiter(definition.defence(level))} defence"
    when :storage then "#{number_with_delimiter(definition.storage_capacity(level))} #{definition.resource} capacity"
    when :build_speed then "#{build_speed_percent(level)} build time"
    when :research then level.positive? ? "Research available" : "Research locked"
    else level.positive? ? "Ships buildable here" : "No ships buildable here"
    end
  end

  # What a technology is currently worth at its level, phrased per effect.
  def technology_effect_label(definition, level)
    percent = (definition.bonus_per_level * level * 100).round

    case definition.effect
    when :extraction_yield then "+#{percent}% extraction"
    when :energy_output then "+#{percent}% energy"
    when :storage then "+#{percent}% storage"
    when :build_speed then "−#{percent}% build time"
    when :propulsion then "−#{percent}% travel time"
    when :weapons then "+#{percent}% fleet attack"
    else "#{percent}% of a fleet survives a failed attack"
    end
  end

  private

  def yield_bonus_percent(level)
    "+#{(Structure::YIELD_BONUS_PER_LEVEL * level * 100).round}%"
  end

  def build_speed_percent(level)
    reduction = 1 - [ 1 - (Structure::BUILD_SPEED_PER_LEVEL * level), PlanetEconomy::MINIMUM_BUILD_SPEED ].max

    "−#{(reduction * 100).round}%"
  end
end
