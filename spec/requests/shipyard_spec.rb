require 'rails_helper'

RSpec.describe "Shipyard", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Shipyard Test",
      size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:user) { empire.player.user }
  let(:planet) { empire.planet }

  def set_shipyard(level)
    planet.structures.find_by(kind: "shipyard").update!(level: level)
  end

  before do
    sign_in(user)
    empire.update!(metal: 500_000, crystal: 500_000, crew: 5_000)
  end

  describe "GET /shipyard" do
    it "lists every hull with its stats" do
      get shipyard_path

      expect(response).to have_http_status(:ok)
      ShipType.all.each { |hull| expect(response.body).to include(hull.name) }
      expect(response.body).to include("atk")
      expect(response.body).to include("cargo")
    end

    it "says the yard is idle when nothing is building" do
      get shipyard_path

      expect(response.body).to include("The yard is idle")
    end

    it "tells the player to build a Shipyard when there is none" do
      set_shipyard(0)

      get shipyard_path

      expect(response.body).to include("No Shipyard on")
    end

    it "shows what a locked hull is missing" do
      get shipyard_path

      expect(response.body).to include("Locked")
      expect(response.body).to include("Shipyard 6")
    end

    it "shows how many of a hull the garrison already holds" do
      get shipyard_path

      expect(response.body).to include("10 held")
    end

    it "shows batches under construction" do
      planet.shipyard.enqueue!("light_fighter", 3)

      get shipyard_path

      expect(response.body).to include("Light Fighter")
      expect(response.body).to include("left")
      expect(response.body).not_to include("The yard is idle")
    end

    it "redirects when the empire has no planet" do
      planet.destroy!

      get shipyard_path

      expect(response).to redirect_to(galaxies_path)
    end

    it "requires a signed-in user" do
      sign_out(user)

      get shipyard_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /shipyard/:id" do
    it "queues the batch and charges the empire" do
      cost = ShipType.find("light_fighter").cost(4)

      expect { post build_ships_path("light_fighter"), params: { quantity: 4 } }
        .to change(ShipOrder, :count).by(1)
        .and change { empire.reload.metal }.by(-cost[:metal])

      expect(flash[:notice]).to match(/4 Light Fighter added to the yard/)
      expect(response).to redirect_to(shipyard_path)
    end

    it "refuses a locked hull and says why" do
      expect { post build_ships_path("battle_cruiser"), params: { quantity: 1 } }
        .not_to change(ShipOrder, :count)

      expect(flash[:alert]).to match(/Shipyard 6/)
    end

    it "refuses a hull whose research is missing" do
      set_shipyard(6)

      post build_ships_path("battle_cruiser"), params: { quantity: 1 }

      expect(flash[:alert]).to match(/Laser Technology 1/)
    end

    it "refuses an unknown hull" do
      post build_ships_path("rowboat"), params: { quantity: 1 }

      expect(flash[:alert]).to match(/unknown ship/)
    end

    it "refuses a quantity below one" do
      post build_ships_path("light_fighter"), params: { quantity: 0 }

      expect(flash[:alert]).to match(/at least one/)
    end

    it "refuses when the empire cannot pay" do
      empire.update!(metal: 0, crystal: 0, crew: 0)

      expect { post build_ships_path("light_fighter"), params: { quantity: 1 } }
        .not_to change(ShipOrder, :count)

      expect(flash[:alert]).to match(/needs/)
    end

    it "redirects when the empire has no planet" do
      planet.destroy!

      post build_ships_path("light_fighter"), params: { quantity: 1 }

      expect(response).to redirect_to(galaxies_path)
    end

    it "answers a Turbo request with streams instead of a redirect" do
      post build_ships_path("light_fighter"), params: { quantity: 2 }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="flash"')
      expect(response.body).to include('target="hud"')
      expect(response.body).to include('action="update" target="planet-main"')
    end

    it "reports a failure through the Turbo stream too" do
      post build_ships_path("battle_cruiser"), params: { quantity: 1 }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Could not build")
    end
  end
end
