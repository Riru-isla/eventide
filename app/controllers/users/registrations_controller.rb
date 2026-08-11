class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]

  def create
    build_resource(sign_up_params)

    ActiveRecord::Base.transaction do
      resource.save!
      create_player_and_empire(resource)
    end

    set_flash_message! :notice, :signed_up
    sign_up(resource_name, resource)
    session[:empire_id] = resource.players.first&.empires&.first&.id
    respond_with resource, location: after_sign_up_path_for(resource)
  rescue ActiveRecord::RecordInvalid => e
    clean_up_passwords resource
    set_minimum_password_length
    flash.now[:alert] = "Could not create empire: #{e.message}"
    render :new, status: :unprocessable_content
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
  end

  def after_sign_up_path_for(_resource)
    galaxy_path(Galaxy.first)
  end

  private

  def create_player_and_empire(user)
    galaxy = Galaxy.first
    player = galaxy.players.create!(
      user: user,
      name: user.username
    )

    sector = available_home_sector(galaxy)
    empire = galaxy.empires.create!(
      player: player,
      role: params[:empire][:role],
      home_sector: sector,
      metal: 500,
      crystal: 500,
      energy: 500
    )

    sector.update!(
      kind: "home",
      empire: empire,
      metal_rate: 30,
      crystal_rate: 30,
      energy_rate: 30,
      defense_strength: 50
    )

    galaxy.fleets.create!(
      empire: empire,
      origin_sector: sector,
      arrival_tick: galaxy.current_tick,
      status: "orbiting",
      ships: { "Fighter" => 10 }
    )
  end

  def available_home_sector(galaxy)
    galaxy.sectors.where(empire_id: nil, npc_faction_id: nil).to_a.sample
  end
end
