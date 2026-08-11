require 'rails_helper'

RSpec.describe "Galaxies", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Request Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:user) { galaxy.players.first.user }

  before { sign_in(user) }

  describe "GET /" do
    it "renders the galaxy map" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(galaxy.name)
    end
  end

  describe "GET /galaxies/:id" do
    it "renders the galaxy" do
      get galaxy_path(galaxy)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ada")
    end
  end
end
