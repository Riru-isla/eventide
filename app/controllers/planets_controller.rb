class PlanetsController < ApplicationController
  def show
    @planet = current_empire&.planet

    redirect_to galaxy_path(Galaxy.first), alert: "Your empire has no planet yet." and return if @planet.nil?

    @empire = current_empire
    @economy = @planet.economy
    @selected = @economy.structures.detect { |structure| structure.kind == selected_key } ||
                @economy.structures.first
  end

  private

  def selected_key
    params[:structure].presence || "metal_extractor"
  end
end
