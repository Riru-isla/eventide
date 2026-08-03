module GalaxiesHelper
  EMPIRE_COLORS = [ "#3b82f6", "#22c55e", "#f59e0b", "#ec4899", "#14b8a6" ].freeze

  def empire_color(index)
    EMPIRE_COLORS[index % EMPIRE_COLORS.size]
  end

  def sector_color(sector)
    return empire_color(sector.empire.galaxy.empires.order(:created_at).pluck(:id).index(sector.empire.id)) if sector.empire
    return sector.npc_faction.color if sector.npc_faction

    case sector.kind
    when "resource" then "#10b981"
    when "core" then "#ef4444"
    else "#4b5563"
    end
  end
end
