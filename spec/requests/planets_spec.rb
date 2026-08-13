require 'rails_helper'

RSpec.describe "Planets", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Planet Request Test",
      size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:empire) { galaxy.empires.first }
  let(:user) { empire.player.user }
  let(:planet) { empire.planet }

  before { sign_in(user) }

  describe "GET /planet — the overview" do
    it "renders the planet overview" do
      get planet_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ERB::Util.html_escape(planet.name))
      expect(response.body).to include("Construction")
      expect(response.body).to include("Extraction")
    end

    it "is the landing page" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Construction")
    end

    it "shows the planet's vital statistics" do
      get planet_path

      expect(response.body).to include("Distance to core")
      expect(response.body).to include("Metal deposit")
    end

    it "shows extractor levels and the energy bus" do
      get planet_path

      expect(response.body).to include("Metal Extractor")
      expect(response.body).to include("Solar Array")
      expect(response.body).to include("Energy bus")
      expect(response.body).to include("Produced")
    end

    it "shows storage against capacity" do
      get planet_path

      expect(response.body).to include("Storage")
      expect(response.body).to include(
        ActiveSupport::NumberHelper.number_to_delimited(empire.storage_capacity(:metal))
      )
    end

    it "warns when mining has stopped at the cap" do
      empire.update!(metal: empire.storage_capacity(:metal))

      get planet_path

      expect(response.body).to include("mining has stopped")
    end

    it "explains an overfilled store rather than calling it full" do
      empire.update!(metal: empire.storage_capacity(:metal) + 250)

      get planet_path

      expect(response.body).to include("over capacity from deliveries")
      expect(response.body).to include("250")
    end

    it "says the queue is idle when nothing is building" do
      get planet_path

      expect(response.body).to include("Idle")
      expect(response.body).to include("Nothing under construction")
    end

    it "lists what is under construction" do
      empire.update!(metal: 10_000, crystal: 10_000)
      planet.queue.enqueue!("solar_array")

      get planet_path

      expect(response.body).to include("1 in queue")
      expect(response.body).to include("tick")
      expect(response.body).not_to include("Nothing under construction")
    end

    it "warns when the planet is in energy deficit" do
      planet.structures.find_by(kind: "metal_extractor").update!(level: 20)

      get planet_path

      expect(response.body).to include("throttled")
    end

    it "redirects to the galaxy when the empire has no planet" do
      planet.destroy!

      get planet_path

      expect(response).to redirect_to(galaxy_path(Galaxy.first))
      expect(flash[:alert]).to match(/no planet/)
    end
  end

  describe "the inbound card" do
    let(:other) do
      EmpireFounder.new(galaxy: galaxy, user: create(:user), name: "Ben", role: "warden").call
    end

    def incoming(mission: "transport", cargo: {}, from: other, ticks: 4)
      galaxy.fleets.create!(
        empire: from, origin_sector: from.planet.sector, target_sector: planet.sector,
        arrival_tick: galaxy.current_tick + ticks, status: "moving", mission: mission,
        ships: { "transport" => 2 }, cargo: cargo
      )
    end

    it "stays hidden when nothing is on its way" do
      get planet_path

      expect(response.body).not_to include("Inbound")
    end

    it "announces a shipment from another commander, with its hold" do
      incoming(cargo: { "metal" => 750 })

      get planet_path

      expect(response.body).to include("Inbound")
      expect(response.body).to include("Shipment")
      expect(response.body).to include("Ben")
      expect(response.body).to include("750")
      expect(response.body).to include("4 ticks out")
    end

    it "flags a hostile fleet differently from a shipment" do
      incoming(mission: "attack", from: other)

      get planet_path

      expect(response.body).to include("Hostile fleet")
      expect(response.body).to include("text-bad")
    end

    it "counts the player's own fleet on its way home" do
      galaxy.fleets.create!(
        empire: empire, origin_sector: planet.sector, target_sector: other.planet.sector,
        arrival_tick: galaxy.current_tick + 2, status: "returning", mission: "transport",
        ships: { "transport" => 1 }, cargo: { "metal" => 40 }
      )

      get planet_path

      expect(response.body).to include("Your fleet returning")
      expect(response.body).to include("40")
    end

    it "says a fleet is arriving now once its tick has come" do
      incoming(ticks: 0)

      get planet_path

      expect(response.body).to include("arriving now")
    end
  end

  describe "GET /planet/resources" do
    it "lists extraction and energy structures, and not facilities" do
      get planet_structures_path(section: "resources")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Metal Extractor")
      expect(response.body).to include("Crystal Extractor")
      expect(response.body).to include("Solar Array")
      expect(response.body).not_to include("Robotics Bay")
    end

    it "groups extraction apart from energy" do
      get planet_structures_path(section: "resources")

      extraction = response.body.index("Extraction<")
      energy = response.body.rindex("Energy<")

      expect(response.body.index("Metal Extractor")).to be_between(extraction, energy)
      expect(response.body.index("Solar Array")).to be > energy
    end

    it "shows the energy bus, since extraction is managed against it" do
      get planet_structures_path(section: "resources")

      expect(response.body).to include("Energy bus")
    end

    it "defaults to inspecting the metal extractor" do
      get planet_structures_path(section: "resources")

      expect(response.body).to include("Metal output")
    end

    it "inspects the structure named in the query string" do
      get planet_structures_path(section: "resources", structure: "solar_array")

      expect(response.body).to include("Energy produced")
    end

    it "falls back to the first structure when given an unknown one" do
      get planet_structures_path(section: "resources", structure: "orbital_casino")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Metal output")
    end
  end

  describe "GET /planet/facilities" do
    it "splits the facilities into named groups" do
      get planet_structures_path(section: "facilities")

      expect(response.body).to include("Resource processing")
      expect(response.body).to include("Storage")
      expect(response.body).to include("Crew support")
      expect(response.body).to include("Infrastructure")
    end

    it "puts each facility under the right group" do
      get planet_structures_path(section: "facilities")

      processing = response.body.index("Resource processing")
      storage = response.body.index("Storage")
      crew = response.body.index("Crew support")

      expect(response.body.index("Metal Refinery")).to be_between(processing, storage)
      expect(response.body.index("Metal Silo")).to be_between(storage, crew)
      expect(response.body.index("Pilot Academy")).to be > crew
    end

    it "lists facilities, and not extractors" do
      get planet_structures_path(section: "facilities")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Refinery")
      expect(response.body).to include("Robotics Bay")
      expect(response.body).to include("Shipyard")
      expect(response.body).not_to include("Metal Extractor")
    end

    it "does not show the energy bus" do
      get planet_structures_path(section: "facilities")

      expect(response.body).not_to include("Energy bus")
    end
  end

  describe "GET /planet/defences" do
    it "lists emplacements, grouped, and nothing else" do
      get planet_structures_path(section: "defences")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Turrets")
      expect(response.body).to include("Shielding")
      expect(response.body).to include("Light Turret")
      expect(response.body).to include("Planetary Shield")
      expect(response.body).not_to include("Metal Extractor")
    end

    it "shows what a locked emplacement needs" do
      get planet_structures_path(section: "defences")

      expect(response.body).to include("Locked")
      expect(response.body).to include("Laser Technology 1")
      expect(response.body).to include("Shipyard 5")
    end

    it "unlocks an emplacement once its prerequisites are met" do
      planet.structures.find_by(kind: "shipyard").update!(level: 3)
      empire.technologies.create!(kind: "laser_technology", level: 1)

      get planet_structures_path(section: "defences", structure: "ion_turret")

      expect(response.body).not_to include("Laser Technology 1")
    end
  end

  describe "live updates" do
    it "subscribes the page to its galaxy's tick stream" do
      get planet_path

      expect(response.body).to include("turbo-cable-stream-source")
    end

    it "asks Turbo to morph and keep scroll on a tick refresh" do
      get planet_path

      expect(response.body).to include('name="turbo-refresh-method" content="morph"')
      expect(response.body).to include('name="turbo-refresh-scroll" content="preserve"')
    end

    it "keeps the starfield out of the morph" do
      get planet_path

      expect(response.body).to match(/id="starfield"[^>]*data-turbo-permanent/)
    end
  end

  it "requires a signed-in user" do
    sign_out(user)

    get planet_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
