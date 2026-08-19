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

  describe "GET /galaxies" do
    it "lists a galaxy the commander already holds, and offers the way in" do
      get galaxies_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(galaxy.name, "You command here", "Enter galaxy")
    end

    it "offers a role picker for a galaxy nobody has joined yet" do
      sign_in(create(:user))

      get galaxies_path

      expect(response.body).to include("Join", "Cultivator")
      expect(response.body).not_to include("You command here")
    end

    it "keeps the administrator controls away from a regular player" do
      sign_in(create(:user))

      get galaxies_path

      expect(response.body).not_to include("Generate galaxy", "Inspect generation")
    end

    it "shows an administrator how to generate and inspect" do
      get galaxies_path

      expect(user).to be_admin
      expect(response.body).to include("Generate galaxy", "Inspect generation")
    end

    it "says so plainly when there is nothing to command in" do
      Galaxy.destroy_all

      get galaxies_path

      expect(response.body).to include("No galaxies have been generated yet")
    end
  end

  describe "GET /galaxies/new" do
    it "renders the settings an administrator can choose" do
      get new_galaxy_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("NPC factions", "Threat level", "Awareness level", "Victory condition")
    end

    it "shows teams as a fixed field, since everybody shares one spawn sector" do
      get new_galaxy_path

      expect(response.body).to include("Teams", "disabled")
    end

    it "turns a regular player away" do
      sign_in(create(:user))

      get new_galaxy_path

      expect(response).to redirect_to(galaxies_path)
      expect(flash[:alert]).to match(/administrator/)
    end
  end

  describe "POST /galaxies" do
    def generate(overrides = {})
      post galaxies_path, params: {
        galaxy: {
          name: "Fresh", size: "tiny", faction_count: 4,
          victory_condition: "reach_the_core", threat_level: "harsh", awareness_level: "alert"
        }.merge(overrides)
      }
    end

    it "builds the galaxy the form asked for and shows how it came out" do
      expect { generate }.to change(Galaxy, :count).by(1)

      built = Galaxy.order(:created_at).last
      expect(built).to have_attributes(
        name: "Fresh", size: "tiny", faction_count: 4,
        threat_level: "harsh", awareness_level: "alert"
      )
      expect(built.npc_factions.count).to eq(4)
      expect(built.sectors.count).to eq(5)
      expect(response).to redirect_to(preview_galaxy_path(built))
    end

    it "hits the garrisons harder at a higher threat level" do
      generate(threat_level: "brutal")

      brutal = Galaxy.order(:created_at).last.npc_factions.by_power.first
      expect(brutal.systems.average(:defense_strength)).to be > GalaxyGenerator::DEFENCE.first
    end

    it "refuses fewer factions than a campaign needs" do
      expect { generate(faction_count: 2) }.not_to change(Galaxy, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Faction count")
    end

    it "turns a regular player away" do
      sign_in(create(:user))

      expect { generate }.not_to change(Galaxy, :count)
      expect(response).to redirect_to(galaxies_path)
    end
  end

  describe "GET /galaxies/:id/preview" do
    it "shows every sector, the core, and where commanders will land" do
      get preview_galaxy_path(galaxy)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(galaxy.core_sector.name, galaxy.spawn_sector.name)
      expect(response.body).to include("core #{galaxy.core_x},#{galaxy.core_y}")
      expect(response.body).to include("<svg", "First fight")
    end

    it "says there is nothing to measure when nobody has joined" do
      empty = GalaxyGenerator.new(name: "Empty", size: "tiny").generate

      get preview_galaxy_path(empty)

      expect(response.body).to include("Nobody has joined")
    end

    it "turns a regular player away" do
      sign_in(create(:user))

      get preview_galaxy_path(galaxy)

      expect(response).to redirect_to(galaxies_path)
    end
  end

  describe "POST /galaxies/:id/join" do
    let(:newcomer) { create(:user, username: "ben") }

    it "founds an empire in that galaxy and starts playing it" do
      sign_in(newcomer)

      expect { post join_galaxy_path(galaxy), params: { role: "warden" } }
        .to change(Empire, :count).by(1)

      expect(newcomer.empires.first.role).to eq("warden")
      expect(newcomer.empires.first.home_system.sector).to eq(galaxy.spawn_sector)
      expect(response).to redirect_to(planet_path)
    end

    it "just switches to an empire the commander already has there" do
      expect { post join_galaxy_path(galaxy) }.not_to change(Empire, :count)

      expect(response).to redirect_to(planet_path)
    end

    it "reports why joining failed rather than falling over" do
      sign_in(newcomer)
      faction = galaxy.npc_factions.first
      galaxy.systems.find_each { |system| system.update!(npc_faction: faction) }

      post join_galaxy_path(galaxy), params: { role: "warden" }

      expect(response).to redirect_to(galaxies_path)
      expect(flash[:alert]).to match(/Could not join/)
    end
  end

  describe "with no empire yet" do
    before { sign_in(create(:user)) }

    it "sends the game screens back to the lobby" do
      get planet_path

      expect(response).to redirect_to(galaxies_path)
      expect(flash[:notice]).to match(/Choose a galaxy/)
    end
  end

  describe "opening a galaxy the commander has no empire in" do
    it "sends them back to the lobby rather than showing somebody else's map" do
      elsewhere = GalaxyGenerator.new(name: "Elsewhere", size: "tiny").generate

      get galaxy_path(elsewhere)

      expect(response).to redirect_to(galaxies_path)
      expect(flash[:alert]).to match(/no empire/)
    end
  end
end
