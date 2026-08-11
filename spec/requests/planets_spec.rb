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

  describe "GET /planet" do
    it "renders the planet screen" do
      get planet_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ERB::Util.html_escape(planet.name))
      expect(response.body).to include("Energy bus")
      expect(response.body).to include("Structures")
    end

    it "is the landing page" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ERB::Util.html_escape(planet.name))
    end

    it "shows every catalogue structure" do
      get planet_path

      Structure.all.each { |structure| expect(response.body).to include(structure.name) }
    end

    it "defaults to inspecting the metal extractor" do
      get planet_path

      expect(response.body).to include("Metal output")
    end

    it "inspects the structure named in the query string" do
      get planet_path(structure: "solar_array")

      expect(response.body).to include("Solar Array")
      expect(response.body).to include("Energy produced")
    end

    it "falls back to the first structure when given an unknown one" do
      get planet_path(structure: "orbital_casino")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Metal output")
    end

    it "warns when the planet is in energy deficit" do
      planet.structures.find_by(kind: "metal_extractor").update!(level: 20)

      get planet_path

      expect(response.body).to include("Deficit")
      expect(response.body).to include("throttled")
    end

    it "redirects to the galaxy when the empire has no planet" do
      planet.destroy!

      get planet_path

      expect(response).to redirect_to(galaxy_path(Galaxy.first))
      expect(flash[:alert]).to match(/no planet/)
    end
  end

  it "requires a signed-in user" do
    sign_out(user)

    get planet_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
