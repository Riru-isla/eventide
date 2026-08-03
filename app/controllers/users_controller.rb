class UsersController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  def new
    redirect_to galaxy_path(Galaxy.first) if current_player
    @galaxy = Galaxy.first
    @player = Player.new
  end

  def create
    @galaxy = Galaxy.first
    player_params = params.require(:player).permit(:name, :username, :password, :password_confirmation)
    @player = Player.new(player_params)

    ActiveRecord::Base.transaction do
      @player.save!
      @empire = @galaxy.empires.create!(
        player: @player,
        role: params[:empire][:role],
        home_sector: available_home_sector,
        metal: 500,
        crystal: 500,
        energy: 500
      )
      @empire.home_sector.update!(
        kind: "home",
        empire: @empire,
        metal_rate: 30,
        crystal_rate: 30,
        energy_rate: 30,
        defense_strength: 50
      )
      @galaxy.fleets.create!(
        empire: @empire,
        origin_sector: @empire.home_sector,
        arrival_tick: @galaxy.current_tick,
        status: "orbiting",
        ships: { "Fighter" => 10 }
      )
    end

    session[:player_id] = @player.id
    session[:empire_id] = @empire.id
    redirect_to galaxy_path(@galaxy), notice: "Welcome to Eventide, #{@player.name}."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Could not create account: #{e.message}"
    @galaxy = Galaxy.first
    render :new, status: :unprocessable_content
  end

  private

  def available_home_sector
    @galaxy.sectors.where(empire_id: nil, npc_faction_id: nil).to_a.sample
  end
end
