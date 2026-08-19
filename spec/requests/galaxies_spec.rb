require 'rails_helper'

RSpec.describe "Galaxies", type: :request do
  let!(:galaxy) do
    GalaxyGenerator.new(
      name: "Request Test",
      size: "tiny",
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

    it "draws only the systems somebody holds" do
      # A galaxy is 22,500 systems at its smallest. Drawing empty space would lock the
      # browser and show nothing; a viewport arrives with fog of war.
      held = galaxy.systems.where.not(empire_id: nil).or(galaxy.systems.where.not(npc_faction_id: nil)).count

      get galaxy_path(galaxy)

      expect(response.body.scan(/class="system"/).size).to eq(held)
      expect(held).to be < galaxy.systems.count
      expect(response.body).to include("galaxy-render")
    end

    it "says how much of the galaxy is being shown" do
      get galaxy_path(galaxy)

      expect(response.body).to include("systems somebody holds")
      expect(response.body).to include(ActiveSupport::NumberHelper.number_to_delimited(galaxy.systems.count))
    end

    it "names each system in a tooltip" do
      get galaxy_path(galaxy)

      expect(response.body).to include("<title>")
      expect(response.body).to include(galaxy.npc_factions.first.name)
    end

    it "no longer carries the prototype's attack form or system picker" do
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

    it "does not run a query per system to colour the map" do
      # This used to resolve each system's owner individually: 225 queries on a 15x15.
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[CACHE SCHEMA TRANSACTION]) }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get galaxy_path(galaxy)
      end

      expect(queries).to be < 40
    end
  end
end
