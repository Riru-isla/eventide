class GalaxiesController < ApplicationController
  def show
    # Everything the map reads per sector is preloaded here. Each of these was an N+1
    # waiting to happen: the owner's name, and the planet whose emplacements make up a
    # sector's total defence.
    @galaxy = Galaxy.includes(sectors: [ { empire: :player }, :npc_faction, { planet: :structures } ]).first!
    @empires = @galaxy.empires.includes(:player).order(:created_at)
    @empire = current_empire

    # Built once and handed to the view. Resolving each sector's colour from the sector
    # itself used to run a query per sector — 225 of them on a 15x15 map.
    @empire_colors = @empires.each_with_index.to_h { |empire, index| [ empire.id, helpers.empire_color(index) ] }
  end
end
