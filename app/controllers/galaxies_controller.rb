class GalaxiesController < ApplicationController
  # The lobby is what you see *before* you have an empire, so it cannot demand one — and
  # neither can inspecting a galaxy, which an administrator does precisely when nobody has
  # joined it yet.
  skip_before_action :require_empire, only: %i[index new create join preview]
  before_action :require_admin, only: %i[new create preview]

  def index
    @galaxies = Galaxy.order(created_at: :desc)
    @empires = user_empires.index_by(&:galaxy_id)
    @commanders = Player.where(galaxy: @galaxies).group(:galaxy_id).count
  end

  def new
    @galaxy = Galaxy.new(default_settings)
  end

  def create
    @galaxy = Galaxy.new(settings.merge(width: dimension, height: dimension))

    return render :new, status: :unprocessable_content unless @galaxy.valid?

    # Inline rather than queued: this takes two to eight seconds, happens rarely, and the
    # whole point is to look at the result immediately.
    generated = GalaxyGenerationJob.perform_now(**settings.to_h.symbolize_keys)
    redirect_to preview_galaxy_path(generated), notice: "Generated #{generated.name}."
  end

  def show
    @galaxy = Galaxy.find(params[:id])
    @empire = user_empires.find_by(galaxy_id: @galaxy.id)

    return redirect_to galaxies_path, alert: "You have no empire in that galaxy." if @empire.nil?

    session[:empire_id] = @empire.id
    load_map
  end

  # The admin's look at how a galaxy came out: every sector, the core, and where commanders
  # will land. Stands in for the fog of war that will later hide all of this from players.
  def preview
    @galaxy = Galaxy.find(params[:id])
    @preview = GalaxyPreview.new(@galaxy)
  end

  def join
    galaxy = Galaxy.find(params[:id])
    empire = user_empires.find_by(galaxy_id: galaxy.id) || found_empire(galaxy)

    session[:empire_id] = empire.id
    redirect_to planet_path, notice: "Commanding in #{galaxy.name}."
  rescue ActiveRecord::RecordInvalid, EmpireFounder::NoHomeSystemAvailable => e
    redirect_to galaxies_path, alert: "Could not join #{galaxy.name}: #{e.message}"
  end

  private

  def found_empire(galaxy)
    EmpireFounder.new(
      galaxy: galaxy, user: current_user, name: current_user.username, role: params[:role]
    ).call
  end

  def settings
    @settings ||= begin
      permitted = params.require(:galaxy)
                        .permit(:name, :size, :faction_count, :victory_condition,
                                :threat_level, :awareness_level)
      permitted.merge(faction_count: permitted[:faction_count].to_i)
    end
  end

  def dimension
    Galaxy::SIZES.dig(settings[:size].to_s, :dimension)
  end

  def default_settings
    {
      name: "Eventide #{Galaxy.count + 1}",
      size: "small",
      faction_count: Galaxy.faction_count_for("small"),
      victory_condition: Galaxy::VICTORY_CONDITIONS.keys.first,
      threat_level: "standard",
      awareness_level: "standard"
    }
  end

  def load_map
    @empires = @galaxy.empires.includes(:player).order(:created_at)

    # Only systems somebody holds are drawn. A galaxy is 17,663 systems at its smallest
    # and 125,627 at its largest — drawing every one would lock the browser, and empty
    # space has nothing to show anyway.
    #
    # This is a stopgap: the real answer is a viewport that renders the neighbourhood a
    # player can actually see, which arrives with fog of war.
    @systems = @galaxy.systems.where.not(empire_id: nil).or(@galaxy.systems.where.not(npc_faction_id: nil))
                      .includes({ empire: :player }, :npc_faction, { planet: :structures })

    # Built once and handed to the view. Resolving each system's colour from the system
    # itself used to run a query per system.
    @empire_colors = @empires.each_with_index.to_h { |empire, index| [ empire.id, helpers.empire_color(index) ] }
  end
end
