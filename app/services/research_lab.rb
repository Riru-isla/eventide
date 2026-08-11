# Starts and finishes an empire's research, and answers what it is allowed to research.
#
# One project at a time: research is the empire's single shared effort, so unlike a
# planet's build queue there is no backlog to order.
class ResearchLab
  class Error < StandardError; end

  def initialize(empire)
    @empire = empire
  end

  def current
    @empire.research_order
  end

  def researching? = current.present?

  def level_of(kind)
    @empire.technology_level(kind)
  end

  # The Research Center that carries out the work. Nil when the empire has no planet.
  def center_level
    @empire.planet&.level_of("research_center").to_i
  end

  # Research goes faster the bigger the Research Center is.
  def speed
    [ 1 - (Technology::CENTER_SPEEDUP_PER_LEVEL * [ center_level - 1, 0 ].max),
      Technology::MINIMUM_RESEARCH_SPEED ].max
  end

  # Prerequisites that are not yet met, as readable text. Empty means it can be started.
  def unmet_requirements(definition)
    missing = []
    missing << "Research Center #{definition.requires_center}" if center_level < definition.requires_center

    definition.requires.each do |kind, level|
      missing << "#{Technology.find!(kind).name} #{level}" if level_of(kind) < level
    end

    missing
  end

  def available?(definition)
    unmet_requirements(definition).empty?
  end

  def cost_for(definition)
    definition.research_cost(level_of(definition.key))
  end

  def ticks_for(definition)
    definition.research_ticks(level_of(definition.key), speed_multiplier: speed)
  end

  def affordable?(definition)
    cost = cost_for(definition)

    @empire.metal >= cost[:metal] && @empire.crystal >= cost[:crystal]
  end

  # Charges the empire and starts the project. Resources are taken up front, as with
  # construction, so nobody can commit to more than they can pay for.
  def start!(kind)
    definition = Technology.find(kind)
    raise Error, "unknown technology" if definition.nil?
    raise Error, "already researching #{current.name}" if researching?

    missing = unmet_requirements(definition)
    raise Error, "#{definition.name} needs #{missing.to_sentence}" if missing.any?

    ActiveRecord::Base.transaction do
      charge!(definition)

      current_tick = @empire.galaxy.current_tick
      ticks = ticks_for(definition)

      @empire.create_research_order!(
        kind: kind,
        target_level: level_of(kind) + 1,
        ticks_required: ticks,
        started_at_tick: current_tick,
        completes_at_tick: current_tick + ticks
      )
    end
  end

  # Applies the project if its tick has arrived.
  def advance!
    order = @empire.research_orders.due(@empire.galaxy.current_tick).first
    return if order.nil?

    technology = @empire.technologies.find_or_create_by!(kind: order.kind) { |record| record.level = 0 }
    technology.update!(level: order.target_level)
    order.destroy!
    @empire.association(:technologies).reset
    @empire.association(:research_order).reset
  end

  private

  def charge!(definition)
    cost = cost_for(definition)

    unless affordable?(definition)
      raise Error, "#{definition.name} level #{level_of(definition.key) + 1} needs " \
                   "#{cost[:metal]} metal and #{cost[:crystal]} crystal"
    end

    @empire.update!(metal: @empire.metal - cost[:metal], crystal: @empire.crystal - cost[:crystal])
  end
end
