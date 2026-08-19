class GalaxiesController < ApplicationController
  def show
    @galaxy = Galaxy.first!
    @empires = @galaxy.empires.includes(:player).order(:created_at)
    @empire = current_empire

    # Only systems somebody holds are drawn. A galaxy is now 22,500 systems at its
    # smallest and 160,000 at its largest — drawing every one would lock the browser,
    # and empty space has nothing to show anyway.
    #
    # This is a stopgap: the real answer is a viewport that renders the neighbourhood a
    # player can actually see, which arrives with fog of war.
    @systems = @galaxy.systems.where.not(empire_id: nil).or(@galaxy.systems.where.not(npc_faction_id: nil))
                      .includes({ empire: :player }, :npc_faction, { planet: :structures })

    # Built once and handed to the view. Resolving each system's colour from the system
    # itself used to run a query per system — 225 of them on a 15x15 map.
    @empire_colors = @empires.each_with_index.to_h { |empire, index| [ empire.id, helpers.empire_color(index) ] }
  end
end
