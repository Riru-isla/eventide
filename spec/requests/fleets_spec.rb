require 'rails_helper'

RSpec.describe "Fleets", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Fleet Request Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:origin) { empire.home_sector }
  let(:target) { galaxy.sectors.npc.first }

  before { sign_in(empire) }

  describe "POST /galaxies/:galaxy_id/fleets" do
    it "creates a moving fleet" do
      expect {
        post galaxy_fleets_path(galaxy), params: {
          fleet: {
            empire_id: empire.id,
            origin_sector_id: origin.id,
            target_sector_id: target.id,
            ships: { "Fighter" => 5 }
          }
        }
      }.to change(Fleet, :count).by(1)

      expect(response).to redirect_to(galaxy_path(galaxy))
      fleet = Fleet.last
      expect(fleet.status).to eq("moving")
      expect(fleet.target_sector).to eq(target)
    end

    it "redirects with an alert on invalid params" do
      post galaxy_fleets_path(galaxy), params: {
        fleet: {
          empire_id: empire.id,
          origin_sector_id: origin.id,
          target_sector_id: 999_999,
          ships: { "Fighter" => 5 }
        }
      }

      expect(response).to redirect_to(galaxy_path(galaxy))
      expect(flash[:alert]).to be_present
    end
  end
end
