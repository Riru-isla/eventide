require 'rails_helper'

RSpec.describe "Systems", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "System Test",
      size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:user) { empire.player.user }

  before { sign_in(user) }

  describe "GET /galaxies/:galaxy_id/systems/:id" do
    it "renders the system" do
      system = empire.home_system
      get galaxy_system_path(galaxy, system)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(system.name)
    end

    it "does not allow viewing another empire's system as owned" do
      other_empire_system = galaxy.systems.find_by(empire: nil, npc_faction: nil)
      get galaxy_system_path(galaxy, other_empire_system)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Build Ships")
    end
  end
end
