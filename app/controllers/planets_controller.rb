class PlanetsController < ApplicationController
  # Resources and Facilities are two views onto the same structure list, split the way
  # the catalogue is categorised. Energy generation sits with Resources, since it is
  # the constraint the extractors are managed against.
  SECTIONS = {
    "resources" => %w[extraction energy],
    "facilities" => %w[facility],
    "defences" => %w[defence]
  }.freeze

  before_action :require_planet

  # The planet's overview: what is building, what it produces, its vital statistics,
  # and anything about to arrive.
  def show
    @economy = @planet.economy
    @inbound = Fleet.bound_for(@planet.system)
                    .includes(:origin_system, :target_system, empire: :player)
                    .order(:arrival_tick)
  end

  def structures
    @economy = @planet.economy
    @section = self.class.section_for(params[:section])
    @structures = self.class.structures_in(@economy, @section)
    @selected = @structures.detect { |structure| structure.kind == params[:structure] } || @structures.first

    render :structures
  end

  class << self
    def section_for(name)
      SECTIONS.key?(name.to_s) ? name.to_s : "resources"
    end

    def structures_in(economy, section)
      categories = SECTIONS.fetch(section)

      economy.structures.select { |structure| categories.include?(structure.definition.category) }
    end

    def path_for(section, **params)
      Rails.application.routes.url_helpers.planet_structures_path(section: section, **params)
    end
  end

  private

  def require_planet
    @empire = current_empire
    @planet = @empire&.planet

    return if @planet

    redirect_to galaxy_path(Galaxy.first), alert: "Your empire has no planet yet."
  end
end
