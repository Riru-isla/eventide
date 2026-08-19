class ResearchController < ApplicationController
  before_action :load_empire

  def show
    @lab = @empire.research
  end

  def create
    @empire.research.start!(params[:id])
    flash.now[:notice] = "Research started: #{Technology.find!(params[:id]).name}."
    respond_with_research
  rescue ResearchLab::Error, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Could not start research: #{e.message}"
    respond_with_research
  end

  private

  def load_empire
    @empire = current_empire

    redirect_to galaxies_path, alert: "Your empire has no planet yet." if @empire&.planet.nil?
  end

  def respond_with_research
    @empire = current_empire.reload
    @lab = @empire.research

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.replace("hud", partial: "shared/hud", locals: { empire: @empire }),
          turbo_stream.update("planet-main", partial: "research/board",
                              locals: { empire: @empire, lab: @lab })
        ]
      end

      format.html do
        flash.keep
        redirect_to research_path
      end
    end
  end
end
