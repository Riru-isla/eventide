require 'rails_helper'

RSpec.describe EmpireFounder, type: :service do
  let(:galaxy) do
    GalaxyGenerator.new(name: "Founder Test", width: 15, height: 15, player_configs: []).generate
  end
  let(:user) { create(:user) }

  def found(name: "Ada", role: "foundry")
    described_class.new(galaxy: galaxy, user: user, name: name, role: role).call
  end

  it "creates a player, empire, home sector, and starting fleet" do
    empire = found

    expect(empire.player.name).to eq("Ada")
    expect(empire.player.user).to eq(user)
    expect(empire.role).to eq("foundry")
    expect(empire.metal).to eq(500)

    home = empire.home_sector
    expect(home.kind).to eq("home")
    expect(home.empire).to eq(empire)

    fleet = empire.fleets.first
    expect(fleet.origin_sector).to eq(home)
    expect(fleet.status).to eq("orbiting")
    expect(fleet.ships).to eq("Fighter" => 10)
  end

  it "clears any NPC faction from the claimed home sector" do
    faction = galaxy.npc_factions.first
    galaxy.sectors.where(empire_id: nil).find_each { |sector| sector.update!(npc_faction: faction) }
    corner = galaxy.sectors.at(0, 0).first
    corner.update!(npc_faction: nil)

    empire = found

    expect(empire.home_sector).to eq(corner)
    expect(empire.home_sector.npc_faction).to be_nil
  end

  it "raises when the galaxy has no free sector left" do
    faction = galaxy.npc_factions.first
    galaxy.sectors.find_each { |sector| sector.update!(npc_faction: faction) }

    expect { found }.to raise_error(described_class::NoHomeSectorAvailable)
  end

  it "does not leave a player behind when founding fails" do
    faction = galaxy.npc_factions.first
    galaxy.sectors.find_each { |sector| sector.update!(npc_faction: faction) }

    expect { found rescue nil }.not_to change(Player, :count)
  end

  it "refuses a second empire for the same user in one galaxy" do
    found(name: "Ada")

    expect { found(name: "Ada Again") }.to raise_error(ActiveRecord::RecordInvalid, /already commands an empire/)
  end
end
