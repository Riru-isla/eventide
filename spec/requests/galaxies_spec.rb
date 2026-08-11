require 'rails_helper'

RSpec.describe "Galaxies", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Request Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  let(:user) { galaxy.players.first.user }

  before { sign_in(user) }

  describe "GET /galaxies/:id" do
    it "renders the galaxy map" do
      get galaxy_path(galaxy)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(galaxy.name)
      expect(response.body).to include("Ada")
    end

    it "draws every sector on the disc" do
      get galaxy_path(galaxy)

      expect(response.body.scan(/class="sector"/).size).to eq(galaxy.sectors.count)
      expect(response.body).to include("galaxy-render")
    end

    it "names each sector in a tooltip" do
      get galaxy_path(galaxy)

      expect(response.body).to include("<title>")
      expect(response.body).to include("Unclaimed")
    end

    it "no longer carries the prototype's attack form or sector picker" do
      get galaxy_path(galaxy)

      expect(response.body).not_to include("Launch from")
      expect(response.body).not_to include("galaxy-map")
      expect(response.body).not_to include("Nothing selected")
    end

    it "lists the commanders and the shared push toward the core" do
      get galaxy_path(galaxy)

      expect(response.body).to include("Commanders")
      expect(response.body).to include("Closest approach to the core")
    end

    it "does not run a query per sector to colour the map" do
      # This used to resolve each sector's owner individually: 225 queries on a 15x15.
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[CACHE SCHEMA TRANSACTION]) }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get galaxy_path(galaxy)
      end

      expect(queries).to be < 40
    end
  end
end
