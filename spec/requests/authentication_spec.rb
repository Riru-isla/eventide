require 'rails_helper'

RSpec.describe "Authentication", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Auth Test",
      size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  it "redirects unauthenticated users to the login page" do
    get galaxy_path(galaxy)
    expect(response).to redirect_to(new_user_session_path)
  end
end
