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
  let(:user) { empire.player.user }
  let(:origin) { empire.home_sector }
  let(:target) { galaxy.sectors.npc.first }
  let(:garrison) { empire.fleets.find_by(origin_sector: origin, status: "orbiting") }

  before { sign_in(user) }

  def dispatch(ships:, origin_id: origin.id, target_id: target.id)
    post galaxy_fleets_path(galaxy), params: {
      fleet: { origin_sector_id: origin_id, target_sector_id: target_id, ships: ships }
    }
  end

  describe "POST /galaxies/:galaxy_id/fleets" do
    it "creates a moving fleet" do
      expect { dispatch(ships: { "Fighter" => 5 }) }.to change(Fleet, :count).by(1)

      expect(response).to redirect_to(galaxy_path(galaxy))
      fleet = Fleet.last
      expect(fleet.status).to eq("moving")
      expect(fleet.target_sector).to eq(target)
      expect(fleet.ships).to eq("Fighter" => 5)
    end

    it "takes the dispatched ships out of the garrison" do
      expect { dispatch(ships: { "Fighter" => 4 }) }
        .to change { garrison.reload.ships["Fighter"] }.from(10).to(6)
    end

    it "disbands the garrison when every ship is dispatched" do
      garrison_id = garrison.id

      expect { dispatch(ships: { "Fighter" => 10 }) }.not_to change(Fleet, :count)

      expect(Fleet.exists?(garrison_id)).to be false
      expect(empire.fleets.moving.first.ships).to eq("Fighter" => 10)
    end

    it "refuses to dispatch more ships than are stationed" do
      expect { dispatch(ships: { "Fighter" => 9_999 }) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/only 10 Fighter stationed/)
      expect(garrison.reload.ships).to eq("Fighter" => 10)
    end

    it "refuses ship types the garrison does not have" do
      expect { dispatch(ships: { "Dreadnought" => 1 }) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/only 0 Dreadnought stationed/)
    end

    it "refuses a dispatch with no ships selected" do
      expect { dispatch(ships: { "Fighter" => 0 }) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/select at least one ship/)
    end

    it "refuses a dispatch from a sector with no garrison" do
      garrison.destroy!

      expect { dispatch(ships: { "Fighter" => 1 }) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/no ships are stationed/)
    end

    it "refuses to dispatch from a sector owned by someone else" do
      other = galaxy.sectors.npc.first

      expect { dispatch(ships: { "Fighter" => 1 }, origin_id: other.id) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to be_present
    end

    it "redirects with an alert on invalid params" do
      dispatch(ships: { "Fighter" => 5 }, target_id: 999_999)

      expect(response).to redirect_to(galaxy_path(galaxy))
      expect(flash[:alert]).to be_present
    end
  end
end
