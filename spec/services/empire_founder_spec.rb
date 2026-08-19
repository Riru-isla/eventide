require 'rails_helper'

RSpec.describe EmpireFounder, type: :service do
  let(:galaxy) do
    GalaxyGenerator.new(name: "Founder Test", size: "tiny", player_configs: []).generate
  end
  let(:user) { create(:user) }

  def found(name: "Ada", role: "foundry")
    described_class.new(galaxy: galaxy, user: user, name: name, role: role).call
  end

  it "creates a player, empire, home system, and starting fleet" do
    empire = found

    expect(empire.player.name).to eq("Ada")
    expect(empire.player.user).to eq(user)
    expect(empire.role).to eq("foundry")
    expect(empire.metal).to eq(500)

    home = empire.home_system
    expect(home.kind).to eq("home")
    expect(home.empire).to eq(empire)

    fleet = empire.fleets.first
    expect(fleet.origin_system).to eq(home)
    expect(fleet.status).to eq("orbiting")
    expect(fleet.ships).to eq("light_fighter" => 10, "transport" => 3)
  end

  it "gives a new commander transports, so they can ship to someone on day one" do
    fleet = found.fleets.first

    expect(fleet.ships["transport"]).to eq(3)
    expect(fleet.cargo_capacity).to eq((10 * 20) + (3 * 500))
  end

  it "creates a planet on the home system with starting structures" do
    empire = found

    planet = empire.planet
    expect(planet).to be_present
    expect(planet.system).to eq(empire.home_system)
    expect(planet.name).to include("Ada")

    expect(planet.structures.pluck(:kind, :level).to_h).to eq(Structure::STARTING_LEVELS)
  end

  it "starts the planet with a positive energy balance" do
    expect(found.planet.economy.energy_balance).to be_positive
  end

  it "clears any NPC faction from the claimed home system" do
    faction = galaxy.npc_factions.first
    galaxy.systems.where(empire_id: nil).find_each { |system| system.update!(npc_faction: faction) }
    corner = galaxy.systems.at(0, 0).first
    corner.update!(npc_faction: nil)

    empire = found

    expect(empire.home_system).to eq(corner)
    expect(empire.home_system.npc_faction).to be_nil
  end

  it "raises when the galaxy has no free system left" do
    faction = galaxy.npc_factions.first
    galaxy.systems.find_each { |system| system.update!(npc_faction: faction) }

    expect { found }.to raise_error(described_class::NoHomeSystemAvailable)
  end

  it "does not leave a player behind when founding fails" do
    faction = galaxy.npc_factions.first
    galaxy.systems.find_each { |system| system.update!(npc_faction: faction) }

    expect { found rescue nil }.not_to change(Player, :count)
  end

  it "refuses a second empire for the same user in one galaxy" do
    found(name: "Ada")

    expect { found(name: "Ada Again") }.to raise_error(ActiveRecord::RecordInvalid, /already commands an empire/)
  end
end
