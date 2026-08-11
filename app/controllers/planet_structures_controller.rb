class PlanetStructuresController < ApplicationController
  class UpgradeError < StandardError; end

  def update
    @planet = current_empire&.planet

    if @planet.nil?
      redirect_to planet_path, alert: "Could not upgrade: your empire has no planet." and return
    end

    structure = upgrade!(@planet, params[:id])
    flash.now[:notice] = "#{structure.name} raised to level #{structure.level}."
    respond_with_planet(structure.kind)
  rescue UpgradeError, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Could not upgrade: #{e.message}"
    respond_with_planet(params[:id])
  end

  private

  # Answers a Turbo request by replacing only the parts that changed, so the browser
  # keeps its scroll position. Anything else falls back to a normal redirect.
  def respond_with_planet(structure_key)
    @empire = current_empire.reload
    @planet = @empire.planet.reload
    @economy = @planet.economy
    @selected = @economy.structures.detect { |structure| structure.kind == structure_key } ||
                @economy.structures.first

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.replace("hud", partial: "shared/hud", locals: { empire: @empire }),
          turbo_stream.update("planet-main", partial: "planets/main",
                              locals: { planet: @planet, economy: @economy,
                                        selected: @selected, empire: @empire })
        ]
      end

      format.html do
        flash.keep
        redirect_to planet_path(structure: structure_key)
      end
    end
  end

  # Upgrades are instant for now. Once game time is settled they become queued
  # builds, and this is where the queue entry gets created instead.
  def upgrade!(planet, kind)
    raise UpgradeError, "unknown structure" if Structure.find(kind).nil?

    ActiveRecord::Base.transaction do
      structure = planet.structures.find_or_create_by!(kind: kind) { |record| record.level = 0 }
      cost = structure.upgrade_cost

      unless affordable?(cost)
        raise UpgradeError, "#{structure.name} level #{structure.level + 1} needs " \
                            "#{cost[:metal]} metal and #{cost[:crystal]} crystal"
      end

      current_empire.update!(
        metal: current_empire.metal - cost[:metal],
        crystal: current_empire.crystal - cost[:crystal]
      )
      structure.update!(level: structure.level + 1)
      structure
    end
  end

  def affordable?(cost)
    current_empire.metal >= cost[:metal] && current_empire.crystal >= cost[:crystal]
  end
end
