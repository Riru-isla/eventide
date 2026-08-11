require 'rails_helper'

RSpec.describe "Planet structures", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Upgrade Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:user) { empire.player.user }
  let(:planet) { empire.planet }

  before { sign_in(user) }

  def upgrade(kind)
    patch planet_structure_path(kind)
  end

  describe "PATCH /planet/structures/:id" do
    it "raises the level and charges the empire" do
      empire.update!(metal: 10_000, crystal: 10_000)
      cost = planet.structures.find_by(kind: "solar_array").upgrade_cost

      expect { upgrade("solar_array") }
        .to change { planet.structures.find_by(kind: "solar_array").reload.level }.by(1)
        .and change { empire.reload.metal }.by(-cost[:metal])
        .and change { empire.reload.crystal }.by(-cost[:crystal])

      expect(flash[:notice]).to match(/Solar Array raised to level 2/)
    end

    it "increases the planet's output" do
      empire.update!(metal: 10_000, crystal: 10_000)

      expect { upgrade("metal_extractor") }
        .to change { empire.reload.planet.economy.output(:metal) }
    end

    it "builds a structure that does not exist yet" do
      empire.update!(metal: 10_000, crystal: 10_000)

      expect { upgrade("refinery") }
        .to change { planet.reload.level_of("refinery") }.from(0).to(1)
    end

    it "refuses when the empire cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { upgrade("solar_array") }
        .not_to change { planet.structures.find_by(kind: "solar_array").reload.level }

      expect(flash[:alert]).to match(/needs/)
    end

    it "does not charge the empire when it cannot pay" do
      empire.update!(metal: 5, crystal: 5)

      expect { upgrade("solar_array") }.not_to change { empire.reload.metal }
    end

    it "refuses an unknown structure" do
      upgrade("orbital_casino")

      expect(flash[:alert]).to match(/unknown structure/)
    end

    it "refuses when the empire has no planet" do
      planet.destroy!

      upgrade("solar_array")

      expect(flash[:alert]).to match(/no planet/)
    end

    it "redirects back to the inspected structure" do
      empire.update!(metal: 10_000, crystal: 10_000)

      upgrade("shipyard")

      expect(response).to redirect_to(planet_path(structure: "shipyard"))
    end

    it "requires a signed-in user" do
      sign_out(user)

      upgrade("solar_array")

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
