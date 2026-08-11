class ShipyardController < ApplicationController
  before_action :load_planet

  def show
    @shipyard = @planet.shipyard
  end

  def create
    @planet.shipyard.enqueue!(params[:id], params[:quantity].to_i)
    flash.now[:notice] = "#{params[:quantity]} #{ShipType.find!(params[:id]).name} added to the yard."
    respond_with_shipyard
  rescue Shipyard::Error, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Could not build: #{e.message}"
    respond_with_shipyard
  end

  private

  def load_planet
    @empire = current_empire
    @planet = @empire&.planet

    redirect_to galaxy_path(Galaxy.first), alert: "Your empire has no planet yet." if @planet.nil?
  end

  def respond_with_shipyard
    @empire = current_empire.reload
    @planet = @empire.planet.reload
    @shipyard = @planet.shipyard

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.replace("hud", partial: "shared/hud", locals: { empire: @empire }),
          turbo_stream.update("planet-main", partial: "shipyard/yard",
                              locals: { planet: @planet, shipyard: @shipyard, empire: @empire })
        ]
      end

      format.html do
        flash.keep
        redirect_to shipyard_path
      end
    end
  end
end
