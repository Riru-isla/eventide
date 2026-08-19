class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
  end

  # A new account has no empire yet. The lobby is where you pick a galaxy and a role.
  def after_sign_up_path_for(_resource)
    galaxies_path
  end
end
