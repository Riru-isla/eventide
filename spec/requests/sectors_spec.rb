require 'rails_helper'

RSpec.describe "Sectors", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Sector Test",
      size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:user) { empire.player.user }

  before { sign_in(user) }

  describe "GET /galaxies/:galaxy_id/sectors/:id" do
    it "renders the sector" do
      sector = empire.home_sector
      get galaxy_sector_path(galaxy, sector)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sector.name)
    end

    it "does not allow viewing another empire's sector as owned" do
      other_empire_sector = galaxy.sectors.find_by(empire: nil, npc_faction: nil)
      get galaxy_sector_path(galaxy, other_empire_sector)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Build Ships")
    end
  end
end
