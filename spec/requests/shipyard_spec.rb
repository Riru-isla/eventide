require 'rails_helper'

RSpec.describe "Shipyard", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Shipyard Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:user) { empire.player.user }
  let(:sector) { empire.home_sector }
  let!(:ship_type) { create(:ship_type, name: "Fighter", metal_cost: 10, crystal_cost: 5, energy_cost: 5) }

  before { sign_in(user) }

  describe "POST /galaxies/:galaxy_id/sectors/:sector_id/shipyard" do
    it "builds ships and subtracts resources" do
      expect {
        post galaxy_sector_shipyard_index_path(galaxy, sector), params: { ship_type_id: ship_type.id, quantity: 5 }
      }.to change { empire.reload.metal }.by(-50)
        .and change { empire.fleets.count }.by(0)

      fleet = empire.fleets.first
      expect(fleet.ships["Fighter"]).to eq(15) # 10 starting + 5 built
      expect(response).to redirect_to(galaxy_sector_path(galaxy, sector))
    end

    it "creates a new fleet if none exists" do
      empire.fleets.destroy_all
      empire.fleets.reload

      expect {
        post galaxy_sector_shipyard_index_path(galaxy, sector), params: { ship_type_id: ship_type.id, quantity: 2 }
      }.to change { Fleet.count }.by(1)

      fleet = empire.fleets.reload.first
      expect(fleet.ships["Fighter"]).to eq(2)
    end

    it "rejects insufficient resources" do
      empire.update!(metal: 0, crystal: 0, energy: 0)

      expect {
        post galaxy_sector_shipyard_index_path(galaxy, sector), params: { ship_type_id: ship_type.id, quantity: 1 }
      }.not_to change { empire.fleets.sum(&:total_ships) }

      expect(response).to redirect_to(galaxy_sector_path(galaxy, sector))
      expect(flash[:alert]).to include("Not enough resources")
    end

    it "rejects non-positive quantity" do
      expect {
        post galaxy_sector_shipyard_index_path(galaxy, sector), params: { ship_type_id: ship_type.id, quantity: 0 }
      }.not_to change { empire.fleets.sum(&:total_ships) }

      expect(response).to redirect_to(galaxy_sector_path(galaxy, sector))
    end
  end
end
