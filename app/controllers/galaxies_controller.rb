class GalaxiesController < ApplicationController
  def show
    @galaxy = Galaxy.includes(sectors: [ :empire, :npc_faction ]).first!
    @empires = @galaxy.empires.includes(:player).order(:created_at)
    @empire = current_empire
    @fleets = @galaxy.fleets.where(empire: @empire)
                      .includes(:empire, origin_sector: [ :empire, :npc_faction ], target_sector: [ :empire, :npc_faction ])
  end
end
