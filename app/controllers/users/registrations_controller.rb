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
  rescue ActiveRecord::RecordInvalid, EmpireFounder::NoHomeSystemAvailable => e
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
    planet_path
  end

  private

  def create_player_and_empire(user)
    EmpireFounder.new(
      galaxy: Galaxy.first,
      user: user,
      name: user.username,
      role: params[:empire][:role]
    ).call
  end
end
