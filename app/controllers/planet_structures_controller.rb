class PlanetStructuresController < ApplicationController
  def update
    planet = current_empire&.planet

    if planet.nil?
      redirect_to planet_path, alert: "Could not queue: your empire has no planet." and return
    end

    order = planet.queue.enqueue!(params[:id])
    flash.now[:notice] = "#{order.name} level #{order.target_level} added to the queue."
    respond_with_section(params[:id])
  rescue BuildQueue::Error, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Could not queue: #{e.message}"
    respond_with_section(params[:id])
  end

  private

  # Answers a Turbo request by replacing only the parts that changed, so the browser
  # keeps its scroll position. Anything else falls back to a normal redirect.
  def respond_with_section(structure_key)
    @empire = current_empire.reload
    @planet = @empire.planet.reload
    @economy = @planet.economy
    @section = PlanetsController.section_for(params[:section])
    @structures = PlanetsController.structures_in(@economy, @section)
    @selected = @structures.detect { |structure| structure.kind == structure_key } || @structures.first

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.replace("hud", partial: "shared/hud", locals: { empire: @empire }),
          turbo_stream.update("planet-main", partial: "planets/structures",
                              locals: { planet: @planet, economy: @economy, section: @section,
                                        structures: @structures, selected: @selected, empire: @empire })
        ]
      end

      format.html do
        flash.keep
        redirect_to PlanetsController.path_for(@section, structure: structure_key)
      end
    end
  end
end
