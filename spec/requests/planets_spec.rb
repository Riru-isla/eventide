require 'rails_helper'

RSpec.describe "Planets", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Planet Request Test",
      width: 11,
      height: 11,
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

    it "warns when a store is full" do
      empire.update!(metal: empire.storage_capacity(:metal) + 1)

      get planet_path

      expect(response.body).to include("income is being lost")
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

  it "requires a signed-in user" do
    sign_out(user)

    get planet_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
