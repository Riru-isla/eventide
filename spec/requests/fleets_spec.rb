require 'rails_helper'

RSpec.describe "Fleets", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Fleet Request Test",
      size: "tiny",
      player_configs: [
        { name: "Ada", role: "foundry" },
        { name: "Ben", role: "warden" }
      ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:other) { galaxy.empires.last }
  let(:user) { empire.player.user }
  let(:origin) { empire.planet.system }
  let(:npc_target) { galaxy.systems.npc.first }
  let(:garrison) { empire.fleets.find_by(origin_system: origin, status: "orbiting") }

  before { sign_in(user) }

  def dispatch(ships:, target_id:, mission: "attack", cargo: nil, origin_id: nil)
    params = { fleet: { target_system_id: target_id, ships: ships, mission: mission } }
    params[:fleet][:cargo] = cargo if cargo
    params[:fleet][:origin_system_id] = origin_id if origin_id

    post dispatch_fleet_path, params: params
  end

  describe "GET /fleets" do
    it "shows what is in orbit and where it can be sent" do
      get fleets_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dispatch")
      expect(response.body).to include("Light Fighter")
      expect(response.body).to include(other.player.name)
    end

    it "says nothing is under way when every ship is home" do
      get fleets_path

      expect(response.body).to include("Every ship you have is in orbit")
    end

    it "lists a fleet under way, with its hold" do
      empire.update!(metal: 5_000)
      dispatch(ships: { "transport" => 2 }, target_id: other.planet.system_id,
               mission: "transport", cargo: { "metal" => 300 })

      get fleets_path

      expect(response.body).to include("Shipment")
      expect(response.body).to include("Hold:")
      expect(response.body).to include("300")
    end

    it "tells the player to build ships when nothing is in orbit" do
      garrison.destroy!

      get fleets_path

      expect(response.body).to include("No ships orbiting your planet")
    end

    it "requires a signed-in user" do
      sign_out(user)

      get fleets_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /fleets — attack" do
    it "creates a moving fleet and takes the ships from the garrison" do
      expect { dispatch(ships: { "light_fighter" => 5 }, target_id: npc_target.id) }
        .to change(Fleet, :count).by(1)
        .and change { garrison.reload.ships["light_fighter"] }.from(10).to(5)

      fleet = Fleet.last
      expect(fleet.status).to eq("moving")
      expect(fleet.mission).to eq("attack")
      expect(fleet.target_system).to eq(npc_target)
    end

    it "refuses to dispatch more ships than are stationed" do
      expect { dispatch(ships: { "light_fighter" => 9_999 }, target_id: npc_target.id) }
        .not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/only 10 Light Fighter stationed/)
    end

    it "refuses a dispatch with no ships selected" do
      dispatch(ships: { "light_fighter" => 0 }, target_id: npc_target.id)

      expect(flash[:alert]).to match(/select at least one ship/)
    end

    it "refuses to leave from a system the empire does not hold" do
      dispatch(ships: { "light_fighter" => 1 }, target_id: npc_target.id, origin_id: npc_target.id)

      expect(flash[:alert]).to be_present
    end

    it "refuses an unknown destination" do
      dispatch(ships: { "light_fighter" => 1 }, target_id: 999_999)

      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /fleets — shipment" do
    before { empire.update!(metal: 5_000, crystal: 5_000) }

    def ship(cargo, ships: { "transport" => 2 })
      dispatch(ships: ships, target_id: other.planet.system_id, mission: "transport", cargo: cargo)
    end

    it "takes the cargo out of the sender's stores at once" do
      expect { ship({ "metal" => 400 }) }.to change { empire.reload.metal }.by(-400)
    end

    it "records the manifest on the fleet" do
      ship({ "metal" => 400, "crystal" => 100 })

      fleet = Fleet.last
      expect(fleet.mission).to eq("transport")
      expect(fleet.manifest).to eq(metal: 400, crystal: 100)
      expect(fleet.target_system).to eq(other.planet.system)
    end

    it "says when it will be back" do
      ship({ "metal" => 100 })

      expect(flash[:notice]).to match(/carrying 100 metal/)
      expect(flash[:notice]).to match(/Back in \d+ ticks/)
    end

    it "refuses more cargo than the hold can take" do
      expect { ship({ "metal" => 5_000 }) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/exceeds the fleet's hold/)
    end

    it "refuses cargo the empire does not have" do
      expect { ship({ "crew" => 999 }) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/available/)
    end

    it "refuses an empty transport" do
      expect { ship({ "metal" => 0 }) }.not_to change(Fleet, :count)

      expect(flash[:alert]).to match(/needs something to carry/)
    end

    it "does not charge the sender when the dispatch fails" do
      expect { ship({ "metal" => 5_000 }) }.not_to change { empire.reload.metal }
    end

    it "answers a Turbo request with streams" do
      post dispatch_fleet_path,
           params: { fleet: { target_system_id: other.planet.system_id, mission: "transport",
                              ships: { "transport" => 1 }, cargo: { "metal" => 100 } } },
           as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="update" target="planet-main"')
    end
  end
end
