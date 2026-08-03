require 'rails_helper'

RSpec.describe "Authentication", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Auth Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  it "redirects unauthenticated users to the login page" do
    get galaxy_path(galaxy)
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq("Please log in to continue.")
  end
end
