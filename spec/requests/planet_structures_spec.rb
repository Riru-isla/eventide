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

  def enqueue(kind, section: "resources")
    patch planet_structure_path(kind, section: section)
  end

  describe "PATCH /planet/structures/:id" do
    it "queues the upgrade and charges the empire up front" do
      empire.update!(metal: 10_000, crystal: 10_000)
      cost = Structure.find("solar_array").upgrade_cost(planet.level_of("solar_array"))

      expect { enqueue("solar_array") }
        .to change { planet.build_orders.count }.by(1)
        .and change { empire.reload.metal }.by(-cost[:metal])
        .and change { empire.reload.crystal }.by(-cost[:crystal])

      expect(flash[:notice]).to match(/Solar Array level 2 added to the queue/)
    end

    it "does not raise the level until the build completes" do
      empire.update!(metal: 10_000, crystal: 10_000)

      expect { enqueue("solar_array") }
        .not_to change { planet.structures.find_by(kind: "solar_array").reload.level }
    end

    it "starts the first order immediately" do
      empire.update!(metal: 10_000, crystal: 10_000)

      enqueue("solar_array")

      expect(planet.build_orders.first).to be_building
    end

    it "leaves later orders waiting for their turn" do
      empire.update!(metal: 100_000, crystal: 100_000)

      enqueue("solar_array")
      enqueue("refinery", section: "facilities")

      expect(planet.build_orders.building.count).to eq(1)
      expect(planet.build_orders.waiting.count).to eq(1)
    end

    it "stacks repeat upgrades on the level already queued" do
      empire.update!(metal: 100_000, crystal: 100_000)

      enqueue("solar_array")
      enqueue("solar_array")

      expect(planet.build_orders.order(:position).map(&:target_level)).to eq([ 2, 3 ])
    end

    it "queues a structure that has not been built yet" do
      empire.update!(metal: 10_000, crystal: 10_000)

      expect { enqueue("refinery", section: "facilities") }
        .to change { planet.build_orders.where(kind: "refinery").count }.by(1)
    end

    it "refuses when the empire cannot pay" do
      empire.update!(metal: 0, crystal: 0)

      expect { enqueue("solar_array") }.not_to change { planet.build_orders.count }
      expect(flash[:alert]).to match(/needs/)
    end

    it "does not charge the empire when it cannot pay" do
      empire.update!(metal: 5, crystal: 5)

      expect { enqueue("solar_array") }.not_to change { empire.reload.metal }
    end

    it "refuses an unknown structure" do
      enqueue("orbital_casino")

      expect(flash[:alert]).to match(/unknown structure/)
    end

    it "refuses when the empire has no planet" do
      planet.destroy!

      enqueue("solar_array")

      expect(flash[:alert]).to match(/no planet/)
    end

    it "redirects back to the section it was queued from" do
      empire.update!(metal: 10_000, crystal: 10_000)

      enqueue("shipyard", section: "facilities")

      expect(response).to redirect_to(planet_structures_path(section: "facilities", structure: "shipyard"))
    end

    it "requires a signed-in user" do
      sign_out(user)

      enqueue("solar_array")

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  # Selecting and queueing must not be page visits, or the browser scrolls back to
  # the top every time you touch a structure.
  describe "PATCH as a Turbo request" do
    it "replaces only the regions that changed, without redirecting" do
      empire.update!(metal: 10_000, crystal: 10_000)

      patch planet_structure_path("solar_array", section: "resources"), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="flash"')
      expect(response.body).to include('target="hud"')
      expect(response.body).to include('action="update" target="planet-main"')
    end

    it "reports the queued level and the charged resources" do
      empire.update!(metal: 10_000, crystal: 10_000)

      patch planet_structure_path("solar_array", section: "resources"), as: :turbo_stream

      expect(response.body).to include("Solar Array level 2 added to the queue")
      expect(response.body).to include(ActiveSupport::NumberHelper.number_to_delimited(empire.reload.metal))
    end

    it "reports failures in the flash without redirecting" do
      empire.update!(metal: 0, crystal: 0)

      patch planet_structure_path("solar_array", section: "resources"), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Could not queue")
    end

    it "keeps the reply on the section it was queued from" do
      empire.update!(metal: 10_000, crystal: 10_000)

      patch planet_structure_path("robotics_bay", section: "facilities"), as: :turbo_stream

      expect(response.body).to include("Robotics Bay")
      expect(response.body).not_to include("Energy bus")
    end
  end

  describe "the management area is a turbo frame" do
    it "wraps the overview" do
      get planet_path

      expect(response.body).to match(/<turbo-frame[^>]*id="planet-main"/)
    end

    it "wraps the structure sections" do
      get planet_structures_path(section: "resources")

      expect(response.body).to match(/<turbo-frame[^>]*id="planet-main"/)
    end
  end
end
